library IEEE;
library xpm;
use xpm.vcomponents.all;
use IEEE.STD_LOGIC_1164.ALL;
use work.sys_config_pkg.all;
use ieee.numeric_std.all;

-- Payload storage for the ID memory, holding one 576-bit Data + CRC vector per
-- ID memory entry.
--
-- A single asymmetric xpm_memory_sdpram cannot store 576 bits per entry: with a
-- 32-bit write port the read port width must be 32 * 2^k (a power-of-two data
-- width ratio), so 576 would have to be padded up to 1024 -- wasting ~44% of the
-- storage and, because BRAM block count is width-bound, ~40% of the BRAM blocks.
--
-- Instead the payload is split across two SDPRAM banks that are read in lockstep
-- (same read address = matched entry index, same READ_LATENCY_B), each with a
-- legal write:read ratio and no padding:
--
--   bank 0 : 512-bit read (ratio 1/16), holds write segments 0..15
--   bank 1 :  64-bit read (ratio  1/2), holds write segments 16..17
--            512 + 64 = 576, 16 + 2 = 18 segments, exactly.
--
-- On read, the two bank outputs are concatenated to reproduce the 576-bit word.
-- On write, the segment index within the entry selects the target bank; only
-- that bank's write-enable is asserted. The write address the master uses is
-- unchanged (entry * SEG_STRIDE + segment), so the software-visible address map
-- is identical to the previous single-bank implementation.
entity payload_memory is
    generic (
        ID_MEM_ENTRY_COUNT : integer := 4
    );
    port (
        clk : in std_logic;

        -- Write port (port A): one 32-bit segment per access.
        -- seg_idx_i is the segment index within the entry (0..PLD_IN_SEG_CNT-1);
        -- entry_idx_i selects the ID memory entry. wr_en_i is the write strobe.
        wr_en_i    : in std_logic;
        entry_idx_i : in std_logic_vector(log2_ceil(ID_MEM_ENTRY_COUNT) - 1 downto 0);
        seg_idx_i   : in std_logic_vector(log2_ceil(PLD_IN_SEG_CNT) - 1 downto 0);
        wr_data_i   : in std_logic_vector(PLD_SEG_IN_WIDTH - 1 downto 0);

        -- Read port (port B): whole 576-bit payload of one entry, latency 2.
        rd_en_i     : in std_logic;
        rd_rst_i    : in std_logic;
        rd_entry_i  : in std_logic_vector(log2_ceil(ID_MEM_ENTRY_COUNT) - 1 downto 0);
        rd_data_o   : out std_logic_vector(PLD_OUT_WIDTH - 1 downto 0)
    );
end payload_memory;

architecture Behavioral of payload_memory is

    -- Segment split between the two banks.
    constant BANK0_SEGS : integer := 16;                    -- segments 0..15
    constant BANK1_SEGS : integer := PLD_IN_SEG_CNT - BANK0_SEGS;  -- segments 16..17

    constant BANK0_RD_WIDTH : integer := BANK0_SEGS * PLD_SEG_IN_WIDTH;  -- 512
    constant BANK1_RD_WIDTH : integer := BANK1_SEGS * PLD_SEG_IN_WIDTH;  -- 64

    -- Read address is shared: one word per entry.
    constant RD_ADDR_WIDTH : integer := log2_ceil(ID_MEM_ENTRY_COUNT);

    -- Write address per bank: entry * <segs in bank> + <segment within bank>.
    constant BANK0_WR_ADDR_WIDTH : integer := log2_ceil(ID_MEM_ENTRY_COUNT * BANK0_SEGS);
    constant BANK1_WR_ADDR_WIDTH : integer := log2_ceil(ID_MEM_ENTRY_COUNT * BANK1_SEGS);

    signal entry_idx_u : unsigned(RD_ADDR_WIDTH - 1 downto 0);
    signal seg_idx_u   : unsigned(seg_idx_i'range);

    -- Per-bank write signals.
    signal b0_wr_en, b1_wr_en : std_logic_vector(0 downto 0);
    signal b0_wr_addr : std_logic_vector(BANK0_WR_ADDR_WIDTH - 1 downto 0);
    signal b1_wr_addr : std_logic_vector(BANK1_WR_ADDR_WIDTH - 1 downto 0);

    -- Per-bank read outputs.
    signal b0_rd_data : std_logic_vector(BANK0_RD_WIDTH - 1 downto 0);
    signal b1_rd_data : std_logic_vector(BANK1_RD_WIDTH - 1 downto 0);

    signal rd_addr : std_logic_vector(RD_ADDR_WIDTH - 1 downto 0);

begin

    entry_idx_u <= unsigned(entry_idx_i);
    seg_idx_u   <= unsigned(seg_idx_i);
    rd_addr     <= rd_entry_i;

    -- Route the incoming segment to the bank that owns it. Only one bank's
    -- write-enable is asserted per access; segments >= PLD_IN_SEG_CNT never
    -- reach here (the caller rejects them).
    write_route : process(all)
    begin
        b0_wr_en <= "0";
        b1_wr_en <= "0";
        b0_wr_addr <= (others => '0');
        b1_wr_addr <= (others => '0');

        -- Only decode an actual write; the address inputs are don't-care (and
        -- may be metavalues at reset) when wr_en_i is low.
        -- Compute the per-bank word address in the integer domain and convert
        -- once. Doing the multiply directly on the narrow unsigned would
        -- truncate to the operand's width (numeric_std "unsigned * natural"),
        -- e.g. entry 7 * 16 wraps to 0 in 3 bits.
        if wr_en_i = '1' and seg_idx_u < BANK0_SEGS then
            -- bank 0: address = entry * BANK0_SEGS + seg
            b0_wr_addr <= std_logic_vector(to_unsigned(
                to_integer(entry_idx_u) * BANK0_SEGS + to_integer(seg_idx_u),
                BANK0_WR_ADDR_WIDTH));
            b0_wr_en <= "1";
        elsif wr_en_i = '1' then
            -- bank 1: address = entry * BANK1_SEGS + (seg - BANK0_SEGS)
            b1_wr_addr <= std_logic_vector(to_unsigned(
                to_integer(entry_idx_u) * BANK1_SEGS + (to_integer(seg_idx_u) - BANK0_SEGS),
                BANK1_WR_ADDR_WIDTH));
            b1_wr_en <= "1";
        end if;
    end process;

    -- Concatenate the two bank outputs back into the 576-bit payload. Bank 0
    -- holds the low 512 bits (segments 0..15), bank 1 the high 64 bits.
    rd_data_o <= b1_rd_data & b0_rd_data;

    -- Bank 0: 512-bit read, ratio 1/16.
    bank0_inst : xpm_memory_sdpram
    generic map (
        ADDR_WIDTH_A => BANK0_WR_ADDR_WIDTH,
        ADDR_WIDTH_B => RD_ADDR_WIDTH,
        AUTO_SLEEP_TIME => 0,
        BYTE_WRITE_WIDTH_A => PLD_SEG_IN_WIDTH,
        CASCADE_HEIGHT => 0,
        CLOCKING_MODE => "common_clock",
        ECC_MODE => "no_ecc",
        MEMORY_INIT_FILE => "none",
        MEMORY_INIT_PARAM => "0",
        MEMORY_OPTIMIZATION => "true",
        MEMORY_PRIMITIVE => "auto",
        MEMORY_SIZE => BANK0_RD_WIDTH * ID_MEM_ENTRY_COUNT,
        MESSAGE_CONTROL => 0,
        READ_DATA_WIDTH_B => BANK0_RD_WIDTH,
        READ_LATENCY_B => 2,
        READ_RESET_VALUE_B => "0",
        RST_MODE_A => "SYNC",
        RST_MODE_B => "SYNC",
        SIM_ASSERT_CHK => 0,
        USE_EMBEDDED_CONSTRAINT => 0,
        USE_MEM_INIT => 0,
        WAKEUP_TIME => "disable_sleep",
        WRITE_DATA_WIDTH_A => PLD_SEG_IN_WIDTH,
        WRITE_MODE_B => "no_change",
        WRITE_PROTECT => 1
    )
    port map (
        dbiterrb => open,
        sbiterrb => open,
        doutb => b0_rd_data,
        addra => b0_wr_addr,
        addrb => rd_addr,
        clka => clk,
        clkb => clk,
        dina => wr_data_i,
        ena => b0_wr_en(0),
        enb => rd_en_i,
        injectdbiterra => '0',
        injectsbiterra => '0',
        regceb => '1',
        rstb => rd_rst_i,
        sleep => '0',
        wea => b0_wr_en
    );

    -- Bank 1: 64-bit read, ratio 1/2.
    bank1_inst : xpm_memory_sdpram
    generic map (
        ADDR_WIDTH_A => BANK1_WR_ADDR_WIDTH,
        ADDR_WIDTH_B => RD_ADDR_WIDTH,
        AUTO_SLEEP_TIME => 0,
        BYTE_WRITE_WIDTH_A => PLD_SEG_IN_WIDTH,
        CASCADE_HEIGHT => 0,
        CLOCKING_MODE => "common_clock",
        ECC_MODE => "no_ecc",
        MEMORY_INIT_FILE => "none",
        MEMORY_INIT_PARAM => "0",
        MEMORY_OPTIMIZATION => "true",
        MEMORY_PRIMITIVE => "auto",
        MEMORY_SIZE => BANK1_RD_WIDTH * ID_MEM_ENTRY_COUNT,
        MESSAGE_CONTROL => 0,
        READ_DATA_WIDTH_B => BANK1_RD_WIDTH,
        READ_LATENCY_B => 2,
        READ_RESET_VALUE_B => "0",
        RST_MODE_A => "SYNC",
        RST_MODE_B => "SYNC",
        SIM_ASSERT_CHK => 0,
        USE_EMBEDDED_CONSTRAINT => 0,
        USE_MEM_INIT => 0,
        WAKEUP_TIME => "disable_sleep",
        WRITE_DATA_WIDTH_A => PLD_SEG_IN_WIDTH,
        WRITE_MODE_B => "no_change",
        WRITE_PROTECT => 1
    )
    port map (
        dbiterrb => open,
        sbiterrb => open,
        doutb => b1_rd_data,
        addra => b1_wr_addr,
        addrb => rd_addr,
        clka => clk,
        clkb => clk,
        dina => wr_data_i,
        ena => b1_wr_en(0),
        enb => rd_en_i,
        injectdbiterra => '0',
        injectsbiterra => '0',
        regceb => '1',
        rstb => rd_rst_i,
        sleep => '0',
        wea => b1_wr_en
    );

end Behavioral;
