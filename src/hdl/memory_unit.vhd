library IEEE;
library xpm;
use xpm.vcomponents.all;
use IEEE.STD_LOGIC_1164.ALL;
use work.sys_config_pkg.all;
use ieee.numeric_std.all;

entity memory_unit is
    generic (
        ID_MEM_ENTRY_COUNT : integer := 4
    );
    Port (
        -- synthesis translate_off
        tb_tree_is_match_o    : out std_logic;
        tb_match_idx_o        : out integer;
        -- synthesis translate_on

        clk                   : in  std_logic;
        reset_n               : in  std_logic;
        sleep_i               : in  std_logic;
        cfg_en_i              : in  std_logic;

        -- AXI Registers of each ID Memory entry
        axi_id_mem_arr_i      : in  id_mem_arr_t(0 to ID_MEM_ENTRY_COUNT - 1);

        -- IO to Parsing Unit 
        bus_id_buffer_i       : in  std_logic_vector(28 downto 0);
        bus_id_buffer_ready_i : in  std_logic;

        -- ID Mem RAM AXI Registers
        axi_data_valid_i      : in  std_logic;
        axi_data_addr_i       : in  std_logic_vector(14 downto 0);
        axi_data_payload_i    : in  std_logic_vector(31 downto 0);
        axi_data_strobe_i     : in  std_logic;

        -- Status & Error Feedback
        ram_write_err_flag_o  : out std_logic;

        fi_frame_o            : out fi_frame_t;
        fi_frame_ready_o      : out std_logic;
        data_vector_ready_o   : out std_logic;
        data_override_o       : out std_logic_vector(0 to 575);

        -- Interrupt Management
        axi_interrupt_resp_i  : in  std_logic;
        interrupt_req_i       : in  std_logic;
        interrupt_o           : out std_logic
    );
end memory_unit;

architecture Behavioral of memory_unit is

    -- CONSTANTS

    -- BRAM & Tree Constants
    constant MATCHER_MAX_TREE_DEPTH : integer := log2_ceil(ID_MEM_ENTRY_COUNT);

    -- AXI & Memory Constants
    -- Payload geometry (PLD_SEG_IN_WIDTH, PLD_OUT_WIDTH, PLD_IN_SEG_CNT) lives
    -- in sys_config_pkg since payload_memory shares it.
    --
    -- The AXI write address is entry * PLD_SEG_STRIDE + segment. The stride is a
    -- power of two so entry and segment are plain bit-slices of the address;
    -- segments PLD_IN_SEG_CNT..PLD_SEG_STRIDE-1 are invalid and rejected.
    -- Storage itself is not padded: payload_memory splits the 18 segments across
    -- two SDPRAM banks (see payload_memory.vhd).
    constant PLD_SEG_STRIDE         : integer := 32;
    constant PLD_IN_OFFSET_WIDTH    : integer := log2_ceil(PLD_SEG_STRIDE);
    constant ADDR_WIDTH_IN          : integer := log2_ceil(ID_MEM_ENTRY_COUNT * PLD_SEG_STRIDE);
    constant ADDR_WIDTH_OUT         : integer := log2_ceil(ID_MEM_ENTRY_COUNT);


    -- SIGNALS --

    -- Root Matcher Node IO
    signal tree_is_match_o          : std_logic;
    signal tree_match_idx_o         : integer;
    signal tree_match_ready_o       : std_logic;

    -- Matching Management Signals
    signal matched_fi_frame_r       : fi_frame_t;
    signal matched_fi_frame         : fi_frame_t;
    signal fi_frame_ready_r         : std_logic;
    signal fi_frame_ready           : std_logic;

    -- BRAM Comp Signals
    -- payload_memory returns exactly the used payload width; no padding.
    signal bram_doutb               : std_logic_vector(PLD_OUT_WIDTH - 1 downto 0);
    signal bram_dina_r              : std_logic_vector(31 downto 0);
    signal bram_dina                : std_logic_vector(31 downto 0);
    signal bram_addra_r             : std_logic_vector(ADDR_WIDTH_IN - 1 downto 0);
    signal bram_addra               : std_logic_vector(ADDR_WIDTH_IN - 1 downto 0);
    signal bram_addrb_r             : std_logic_vector(ADDR_WIDTH_OUT - 1 downto 0);
    signal bram_addrb               : std_logic_vector(ADDR_WIDTH_OUT - 1 downto 0);
    signal bram_ena_r               : std_logic;
    signal bram_ena                 : std_logic;
    signal bram_enb_r               : std_logic;
    signal bram_enb                 : std_logic;
    signal bram_wea_r               : std_logic_vector(0 downto 0);
    signal bram_wea                 : std_logic_vector(0 downto 0);
    signal bram_rstb_r              : std_logic;
    signal bram_rstb                : std_logic;

    -- RAM Management Signals
    signal data_vector_ready_r      : std_logic;
    signal data_vector_ready        : std_logic;

    type ram_read_state_t is (AWAIT_MATCH, AWAIT_MEM, READY, SKIP_READ);
    signal ram_read_state_r         : ram_read_state_t;
    signal ram_read_state           : ram_read_state_t;

    signal ram_write_err_r          : std_logic;
    signal ram_write_err            : std_logic;
    signal mem_rd_latency_sr_r      : std_logic_vector(1 downto 0);
    signal mem_rd_latency_sr        : std_logic_vector(1 downto 0);

    -- Interrupt Management
    signal interrupt_hold           : std_logic;
    signal interrupt_hold_r         : std_logic;

    -- Debug Signals
    attribute mark_debug            : string;
    signal debug_data_32            : std_logic_vector(31 downto 0);


    component id_matcher
        generic (
            LEAF_IDX       : integer;
            NODE_DEPTH     : integer;
            MAX_TREE_DEPTH : integer 
        );
        port (
            clk                   : in  std_logic;
            reset_n               : in  std_logic;
            bus_id_buffer_ready_i : in  std_logic;
            bus_id_buffer_i       : in  std_logic_vector(28 downto 0);
            axi_id_mem_arr_i      : in  id_mem_arr_t;
            sleep_i               : in  std_logic;
            is_match_o            : out std_logic;
            match_ready_o         : out std_logic;
            leaf_idx_o            : out integer
        );
    end component;

begin

    debug_data_32 <= bram_doutb(31 downto 0);

    -- synthesis translate_off
    tb_match_idx_o     <= tree_match_idx_o;
    tb_tree_is_match_o <= tree_is_match_o; 
    -- synthesis translate_on

    id_matcher_inst : id_matcher
    generic map (
        LEAF_IDX       => 0,
        NODE_DEPTH     => 0,
        MAX_TREE_DEPTH => MATCHER_MAX_TREE_DEPTH
    )
    port map (
        clk                   => clk,
        reset_n               => reset_n,
        bus_id_buffer_ready_i => bus_id_buffer_ready_i,
        bus_id_buffer_i       => bus_id_buffer_i,
        axi_id_mem_arr_i      => axi_id_mem_arr_i,
        sleep_i               => sleep_i,
        is_match_o            => tree_is_match_o,
        match_ready_o         => tree_match_ready_o,
        leaf_idx_o            => tree_match_idx_o
    );

    -- Payload storage. Two SDPRAM banks internally (see payload_memory.vhd);
    -- entry and segment are the high / low slices of the buffered write address
    -- (stride PLD_SEG_STRIDE is a power of two). The write-side guard has
    -- already rejected any segment >= PLD_IN_SEG_CNT, so only valid segments
    -- reach the component. wea and ena are asserted together on every write.
    payload_memory_inst : entity work.payload_memory
    generic map (
        ID_MEM_ENTRY_COUNT => ID_MEM_ENTRY_COUNT
    )
    port map (
        clk         => clk,
        wr_en_i     => bram_wea_r(0),
        entry_idx_i => bram_addra_r(ADDR_WIDTH_IN - 1 downto PLD_IN_OFFSET_WIDTH),
        seg_idx_i   => bram_addra_r(log2_ceil(PLD_IN_SEG_CNT) - 1 downto 0),
        wr_data_i   => bram_dina_r,
        rd_en_i     => bram_enb_r,
        rd_rst_i    => bram_rstb_r,
        rd_entry_i  => bram_addrb_r,
        rd_data_o   => bram_doutb
    );

    fi_frame_o           <= matched_fi_frame_r;
    fi_frame_ready_o     <= fi_frame_ready_r;
    ram_write_err_flag_o <= ram_write_err_r;
    data_override_o      <= bram_doutb;
    data_vector_ready_o  <= data_vector_ready_r;
    interrupt_o          <= interrupt_hold_r;

    -- Note: "is_match" and "match_idx" are both owned by the matcher tree
    -- Therefore they dont need additional registers here 
    extract_fi_frame : process(all)
    begin
        matched_fi_frame <= matched_fi_frame_r;
        fi_frame_ready   <= fi_frame_ready_r;
        if sleep_i then
            matched_fi_frame <= fi_frame_init;
            fi_frame_ready   <= '0';
        elsif tree_is_match_o = '1' and tree_match_ready_o = '1' then
            matched_fi_frame <= axi_id_mem_arr_i(tree_match_idx_o).fi_frame;
            fi_frame_ready   <= '1';
        end if;
    end process;

    write_axi_to_ram : process(all)
    begin 
        bram_dina     <= (others => '0');
        bram_addra    <= (others => '0');
        bram_ena      <= '0';
        bram_wea      <= "0";
        ram_write_err <= ram_write_err_r;

        if cfg_en_i and axi_data_valid_i and axi_data_strobe_i then
            if unsigned(axi_data_addr_i) < ID_MEM_ENTRY_COUNT * PLD_SEG_STRIDE
               and unsigned(axi_data_addr_i(PLD_IN_OFFSET_WIDTH - 1 downto 0)) < PLD_IN_SEG_CNT then
                bram_dina     <= axi_data_payload_i;
                bram_addra    <= axi_data_addr_i(ADDR_WIDTH_IN - 1 downto 0);
                bram_ena      <= '1';
                bram_wea      <= "1";
                ram_write_err <= '0';
            else
                ram_write_err <= '1';
            end if;
        end if;
    end process;

    -- Note: FI-Frames are not guaranteed to be valid by the Master; validation is handled by the Override Unit.
    write_ram_to_buffer : process(all)
    begin
        bram_rstb         <= '0';
        bram_enb          <= '0';
        bram_addrb        <= bram_addrb_r;
        data_vector_ready <= data_vector_ready_r;
        mem_rd_latency_sr <= mem_rd_latency_sr_r;
        ram_read_state    <= ram_read_state_r;

        if sleep_i then
            bram_rstb         <= '1';
            data_vector_ready <= '0';
            ram_read_state    <= AWAIT_MATCH;
            mem_rd_latency_sr <= "01";
        else 
            case ram_read_state_r is
                when AWAIT_MATCH =>
                    if fi_frame_ready_r then
                        -- Check if the Data bit is HI, if not avoid unncesessary reads
                        if matched_fi_frame_r.fi_type = FI_DATA then
                            bram_addrb     <= std_logic_vector(to_unsigned(tree_match_idx_o, bram_addrb_r'length));
                            bram_enb       <= '1';
                            ram_read_state <= AWAIT_MEM;
                        else
                            ram_read_state <= SKIP_READ;
                        end if;
                    end if;
                -- Count cycles until the BRAM_OUT is ready
                when AWAIT_MEM =>
                    if mem_rd_latency_sr_r(1) = '1' then
                        ram_read_state <= READY;
                    else
                        mem_rd_latency_sr <= mem_rd_latency_sr_r(0) & '0';
                    end if;
                when READY | SKIP_READ =>
                    if sleep_i = '1' then
                        ram_read_state <= AWAIT_MATCH;
                    end if;
                    data_vector_ready <= '1';
            end case; 
        end if;
    end process;

    interrupt_mgmt : process(all)
    begin
        interrupt_hold <= interrupt_hold_r;
        if interrupt_req_i then
            interrupt_hold <= '1';
        elsif axi_interrupt_resp_i then
            interrupt_hold <= '0';
        end if;
    end process;

    clk_reg_assign : process(all)
    begin
        if rising_edge(clk) then
            if reset_n = '0' then
                matched_fi_frame_r  <= fi_frame_init;
                data_vector_ready_r <= '0';
                bram_dina_r         <= (others => '0');
                bram_addra_r        <= (others => '0');
                bram_addrb_r        <= (others => '0');
                bram_ena_r          <= '0';
                bram_enb_r          <= '0';
                bram_wea_r          <= "0";
                bram_rstb_r         <= '0';
                ram_read_state_r    <= AWAIT_MATCH;
                ram_write_err_r     <= '0';
                fi_frame_ready_r    <= '0';
                mem_rd_latency_sr_r <= "01";
                interrupt_hold_r    <= '0';
            else
                matched_fi_frame_r  <= matched_fi_frame;
                data_vector_ready_r <= data_vector_ready;
                bram_dina_r         <= bram_dina;
                bram_addra_r        <= bram_addra;
                bram_addrb_r        <= bram_addrb;
                bram_ena_r          <= bram_ena;
                bram_enb_r          <= bram_enb;
                bram_wea_r          <= bram_wea;
                bram_rstb_r         <= bram_rstb;
                ram_read_state_r    <= ram_read_state;
                ram_write_err_r     <= ram_write_err;
                fi_frame_ready_r    <= fi_frame_ready;
                mem_rd_latency_sr_r <= mem_rd_latency_sr; 
                interrupt_hold_r    <= interrupt_hold;
            end if;
        end if;
    end process;

end Behavioral;