library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.can_test_vec_pkg.all;
use work.sys_config_pkg.all;

entity tb_func_can_fsm is
end tb_func_can_fsm;

architecture Behavioral of tb_func_can_fsm is

    -- Spy Signals
    signal tb_ctrl_buffer : STD_LOGIC_VECTOR (3 downto 0);
    signal tb_data_buffer : STD_LOGIC_VECTOR (511 downto 0);
    signal tb_crc_stf_buffer : STD_LOGIC_VECTOR (3 downto 0);
    signal tb_crc_buffer : STD_LOGIC_VECTOR (20 downto 0);
    signal tb_id_buffer : STD_LOGIC_VECTOR (28 downto 0);
    signal tb_dlc_buffer : STD_LOGIC_VECTOR (3 downto 0);


    signal clk: STD_LOGIC := '0';
    signal reset_n: STD_LOGIC := '1';
    signal sample_i: STD_LOGIC := '0';
    signal sample_strb_i: STD_LOGIC := '0';
    signal eof_stat_o: STD_LOGIC := '0';
    signal brs_pend_stat_o : STD_LOGIC := '0';
    signal crc_del_pend_stat_o : STD_LOGIC := '0';
    signal err_stat_o : STD_LOGIC := '0';
    signal hard_sync_req_o : STD_LOGIC := '0';
    signal sleep_i : STD_LOGIC := '0';
    

    ----
    -- LEGACY Definitions
    ----

    -- 2. Type Definitions (Record + Padding method)
    type t_can_frame is record
        id : std_logic_vector(28 downto 0);
        dlc : std_logic_vector(3 downto 0);
        ctrl : std_logic_vector(3 downto 0);
        data : std_logic_vector(95 downto 0);
        crc_stf : std_logic_vector(3 downto 0);
        crc : std_logic_vector(20 downto 0);
        raw_frame : std_logic_vector(0 to 127);
        raw_frame_len : integer;
    end record;

    type t_can_frame_array is array (natural range <>) of t_can_frame; 

    constant C_TEST_FRAMES : t_can_frame_array(0 to 7) := (
        -- Test 0: Basic CAN 2.0 Vector
        0 => (
            id            => "000000000000000000" & "10101010101", -- 11-bit ID padded to 29
            dlc           => "0000",
            ctrl          => "0000", -- fdf(0) & r1(0) & brs(0) & esi(0)
            data          => (others => '0'),
            crc_stf       => (others => '0'),
            crc           => "000000" & "101010101010101", -- 15-bit CRC padded to 21
            raw_frame     => x"55504AAABFE000000000000000000000",
            raw_frame_len => 43
        ),

        -- Test 1: Basic CAN 2.0 Vector with 8 Bit Data width
        1 => (
            id            => "000000000000000000" & "10101010101",
            dlc           => "0001",
            ctrl          => "0000",
            data          => x"0000000000000000000000" & "01010101", -- 8 bits data padded to 96
            crc_stf       => (others => '0'),
            crc           => "000000" & "101010101010101",
            raw_frame     => x"5550555AAABFE0000000000000000000",
            raw_frame_len => 51
        ),

        -- Test 2: Basic CAN 2.0 Vector with 8 Bit Data width and Ext ID
        2 => (
            -- ID (11) & IDX (18) = 29 bits
            id            => "10101010101" & "101010101010101010", 
            dlc           => "0001",
            ctrl          => "0000",
            data          => x"0000000000000000000000" & "01010101",
            crc_stf       => (others => '0'),
            crc           => "000000" & "101010101010101",
            raw_frame     => x"555EAAAA0955AAABFE00000000000000",
            raw_frame_len => 71
        ),

        -- Test 3: CAN FD Vector
        3 => (
            id            => "000000000000000000" & "10101010101",
            dlc           => "0000",
            ctrl          => "1011", -- fdf(1) & r1(0) & brs(1) & esi(1)
            data          => (others => '0'),
            crc_stf       => "0110",
            -- 17-bit CRC padded to 21
            crc           => "0000" & "01000011001010101", 
            raw_frame     => x"5552C2D498B5FF800000000000000000",
            raw_frame_len => 57
        ),

        -- Test 4: CRC after DLC, BS before last DLC
        4 => (
            id            => "000000000000000000" & "10101010101",
            dlc           => "0000",
            ctrl          => "1100", -- fdf(1) & r1(1) & brs(0) & esi(0)
            data          => (others => '0'),
            crc_stf       => "1100",
            crc           => "0000" & "01000011001010101",
            raw_frame     => x"555305CA4C5AFFC00000000000000000",
            raw_frame_len => 58
        ),

        -- Test 5: CRC after DLC, BS after last DLC bit
        5 => (
            id            => "000000000000000000" & "10101010101",
            dlc           => "0000",
            ctrl          => "1110", -- fdf(1) & r1(1) & brs(1) & esi(0)
            data          => (others => '0'),
            crc_stf       => "0100",
            crc           => "0000" & "00100011001010101",
            raw_frame     => x"555382494C5AFFC00000000000000000",
            raw_frame_len => 58
        ),

        -- Test 6: CRC after DATA
        6 => (
            id            => "000000000000000000" & "10101010101",
            dlc           => "0001",
            ctrl          => "1110", -- fdf(1) & r1(1) & brs(1) & esi(0)
            data          => x"0000000000000000000000" & "01010101",
            crc_stf       => "0100",
            crc           => "0000" & "00100011001010101",
            raw_frame     => x"555385549298B5FF8000000000000000",
            raw_frame_len => 65
        ),

        -- Test 7: Stuffing Stress Test
        7 => (
            id            => "000000000000000000" & "00000000000", -- idx (18) & id (11)
            dlc           => "0000",
            ctrl          => "1000", -- fdf(1) & r1(0) & brs(0) & esi(0)
            data => x"000000000000000000000000",
            crc_stf       => "0000",
            crc           => "0000" & "00000000000000000",
            raw_frame     => x"0411041044121084217F800000000000",
            raw_frame_len => 81
        )
    );

    signal curr_test_vector_idx : integer := 0;
    signal curr_test_idx : integer := 0;
    constant clk_period : time := 10 ns;


begin
uut: entity work.can_fsm PORT MAP (
        clk                  => clk,
        reset_n              => reset_n,
        sample_i            => sample_i,
        sample_strb_i      => sample_strb_i,
        eof_stat_o         => eof_stat_o,
        brs_pend_stat_o => brs_pend_stat_o,
        crc_del_pend_stat_o => crc_del_pend_stat_o,
        err_stat_o => err_stat_o, 
        hard_sync_req_o   => hard_sync_req_o,
        sleep_i             => sleep_i,

        -- Debug Mapping
        tb_ctrl_buffer_o    => tb_ctrl_buffer,
        tb_data_buffer_o    => tb_data_buffer,
        tb_crc_stf_buffer_o => tb_crc_stf_buffer,
        tb_crc_buffer_o     => tb_crc_buffer,
        tb_id_buffer_o      => tb_id_buffer,
        tb_dlc_buffer_o     => tb_dlc_buffer
    );

    clk_process : process
    begin 
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;
    
    -- Change into a loop 
    sim_sample_wire : process
    begin



        reset_n <= '0';
        -- Recessive Bus
        sample_i <= '1';
        sample_strb_i <= '0';
        -- Wait for 5 Cycles (Not really necessary, but for better overview)
        
        for k in 1 to 3 loop
            wait until rising_edge(clk);
        end loop;

        reset_n <= '1';
        for i in D_TEST_FRAMES'range loop
            curr_test_vector_idx <= i;
            
            wait until rising_edge(clk);
            sleep_i <= '1';
            sample_i <= '1'; 
            sample_strb_i <= '0';
            for k in 1 to 3 loop
                wait until rising_edge(clk);
            end loop;
            sleep_i <= '0';
            wait until rising_edge(clk);

            for bit_idx in 0 to D_TEST_FRAMES(i).raw_frame_len - 6 loop
                sample_i <= D_TEST_FRAMES(i).raw_frame(bit_idx);
                curr_test_idx <= bit_idx;
                sample_strb_i <= '1';
                wait until rising_edge(clk);
                sample_strb_i <= '0';
                for k in 1 to 3 loop
                    wait until rising_edge(clk);
                end loop;
            end loop;

            sleep_i <= '1'; 
            wait until rising_edge(clk);
            
            -- --------------------------------------------------------
            -- ASSERTIONS
            -- --------------------------------------------------------
            
            -- 1. Check ID
            assert tb_id_buffer = D_TEST_FRAMES(i).id 
                report "Test Vector " & integer'image(i) & " Failed: ID Mismatch." 
                severity failure;

            -- 2. Check DLC
            assert tb_dlc_buffer = D_TEST_FRAMES(i).dlc 
                report "Test Vector " & integer'image(i) & " Failed: DLC Mismatch." 
                severity failure;

            -- 3. Check Control (CTRL)
            assert tb_ctrl_buffer = D_TEST_FRAMES(i).ctrl 
                report "Test Vector " & integer'image(i) & " Failed: CTRL Mismatch." 
                severity failure;

            -- 4. Check Data
            assert tb_data_buffer(MAX_DATA_BITS - 1 downto 0) = D_TEST_FRAMES(i).data 
                report "Test Vector " & integer'image(i) & " Failed: DATA Mismatch." 
                severity failure;

            -- 4. Check Data
            --assert tb_data_buffer(95 downto 0) = D_TEST_FRAMES(i).data 
            --    report "Test Vector " & integer'image(i) & " Failed: DATA Mismatch." 
            --    severity failure;

            -- 5. Check CRC Stuff Count (CRC_STF)
            assert tb_crc_stf_buffer = D_TEST_FRAMES(i).crc_stf 
                report "Test Vector " & integer'image(i) & " Failed: CRC_STF Mismatch." 
                severity failure;

            -- 6. Check CRC
            assert tb_crc_buffer = D_TEST_FRAMES(i).crc 
                report "Test Vector " & integer'image(i) & " Failed: CRC Mismatch." 
                severity failure;
                
            -- Optional success message for the specific vector
            report "Test Vector " & integer'image(i) & " Complete." severity note;

        end loop;

        assert false report "Test Successful!" severity failure;
    end process;

end Behavioral;
