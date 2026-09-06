library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.sys_config_pkg.all;

entity id_matcher is
    generic (
        LEAF_IDX       : integer;
        NODE_DEPTH     : integer;            
        MAX_TREE_DEPTH : integer := 2
    );
    Port ( 
        clk                   : in  std_logic;
        reset_n               : in  std_logic;

        -- HI -> Buffered ID data is assembled and can be parsed
        bus_id_buffer_ready_i : in  std_logic;
        bus_id_buffer_i       : in  std_logic_vector(28 downto 0);
        axi_id_mem_arr_i      : in  id_mem_arr_t;
        sleep_i               : in  std_logic;

        -- Recursive Callbacks to the parent / top
        match_ready_o         : out std_logic;
        is_match_o            : out std_logic;
        leaf_idx_o            : out integer
    );
end id_matcher;

architecture Behavioral of id_matcher is

    component id_matcher is
        generic (
            LEAF_IDX       : integer;
            NODE_DEPTH     : integer;            
            MAX_TREE_DEPTH : integer := 2
        );
        Port ( 
            clk                   : in  std_logic;
            reset_n               : in  std_logic;
            bus_id_buffer_ready_i : in  std_logic;

            bus_id_buffer_i       : in  std_logic_vector(28 downto 0);
            axi_id_mem_arr_i      : in  id_mem_arr_t;
            sleep_i               : in  std_logic;

            match_ready_o         : out std_logic;
            is_match_o            : out std_logic;
            leaf_idx_o            : out integer
        );
    end component id_matcher;

begin

    GEN_CHILD_NODES : if (NODE_DEPTH < MAX_TREE_DEPTH) generate

        signal lc_match_ready : std_logic;
        signal lc_is_match    : std_logic;
        signal lc_leaf_idx    : integer;
        
        signal rc_match_ready : std_logic;
        signal rc_is_match    : std_logic;
        signal rc_leaf_idx    : integer;

        signal pt_leaf_idx_r  : integer;
        signal pt_leaf_idx    : integer;
        
        signal is_match_r     : std_logic;
        signal is_match       : std_logic;

        signal match_ready_r  : std_logic;
        signal match_ready    : std_logic;

    begin

        match_ready_o <= match_ready_r;
        is_match_o    <= is_match_r;
        leaf_idx_o    <= pt_leaf_idx_r;

        left_child_node : id_matcher
            generic map (
                LEAF_IDX       => LEAF_IDX,
                NODE_DEPTH     => NODE_DEPTH + 1,
                MAX_TREE_DEPTH => MAX_TREE_DEPTH
            )
            port map (
                clk                   => clk,
                reset_n               => reset_n,
                bus_id_buffer_ready_i => bus_id_buffer_ready_i,

                bus_id_buffer_i       => bus_id_buffer_i,
                axi_id_mem_arr_i      => axi_id_mem_arr_i,
                sleep_i               => sleep_i,  
                
                is_match_o            => lc_is_match,
                match_ready_o         => lc_match_ready,
                leaf_idx_o            => lc_leaf_idx
            );

        right_child_node : id_matcher
            generic map (
                LEAF_IDX       => LEAF_IDX + 2 ** (MAX_TREE_DEPTH - NODE_DEPTH - 1),
                NODE_DEPTH     => NODE_DEPTH + 1,
                MAX_TREE_DEPTH => MAX_TREE_DEPTH
            )
            port map (
                clk                   => clk,
                reset_n               => reset_n,
                bus_id_buffer_ready_i => bus_id_buffer_ready_i,

                bus_id_buffer_i       => bus_id_buffer_i,
                axi_id_mem_arr_i      => axi_id_mem_arr_i,
                sleep_i               => sleep_i,  
                
                is_match_o            => rc_is_match,
                match_ready_o         => rc_match_ready,
                leaf_idx_o            => rc_leaf_idx
            );

        child_node_integrate : process(all)
        begin
            if sleep_i = '1' then
                is_match    <= '0';
                pt_leaf_idx <= 0;
                match_ready <= '0';
            else
                is_match    <= lc_is_match or rc_is_match;
                match_ready <= lc_match_ready and rc_match_ready;
                pt_leaf_idx <= lc_leaf_idx when lc_is_match else rc_leaf_idx;
            end if;
        end process;

        clg_reg_assign : process(reset_n, clk)
        begin
            if reset_n = '0' then
                is_match_r    <= '0';
                match_ready_r <= '0';
                pt_leaf_idx_r <= 0;
            elsif rising_edge(clk) then
                is_match_r    <= is_match;
                match_ready_r <= match_ready;
                pt_leaf_idx_r <= pt_leaf_idx;
            end if;
        end process;

    end generate GEN_CHILD_NODES;

    -- Logic for a leaf node. Fully Combinational, no register buffering 
    LEAF_NODE : if (NODE_DEPTH = MAX_TREE_DEPTH) generate
        signal id_match_res : std_logic_vector(28 downto 0);
        constant one_id     : std_logic_vector(28 downto 0) := (others => '1');
    begin

        match_ready_o <= '1';
        -- Strict comparison with value in array followed up by loosening via "Don't care" 1`s mask 
        id_match_res  <= (bus_id_buffer_i xnor axi_id_mem_arr_i(LEAF_IDX).id_value) or axi_id_mem_arr_i(LEAF_IDX).id_mask;
        is_match_o    <= '1' when id_match_res = one_id and bus_id_buffer_ready_i = '1' else '0';
        leaf_idx_o    <= LEAF_IDX;

    end generate LEAF_NODE;

end Behavioral;