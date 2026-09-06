
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.sys_config_pkg.all;
use ieee.numeric_std.all;


entity tb_memory_unit is
end;

architecture bench of tb_memory_unit is
    -- Clock period
    constant clk_period : time := 12 ns;
    -- Generics
    constant ID_MEM_ENTRY_COUNT : integer := 8;
    -- Ports
    signal clk : std_logic := '0';
    signal reset_n : std_logic := '1';
    signal sleep_i : std_logic := '0';
    signal cfg_en_i : std_logic := '0';
    signal axi_id_mem_arr_i : id_mem_arr_t(0 to ID_MEM_ENTRY_COUNT - 1);
    signal bus_id_buffer_i : std_logic_vector(28 downto 0);
    signal bus_id_buffer_ready_i : std_logic;
    signal fi_frame_o : fi_frame_t;
    signal axi_data_valid_i : std_logic;
    signal axi_data_addr_i : std_logic_vector(14 downto 0);
    signal axi_data_payload_i : std_logic_vector(31 downto 0);
    signal axi_data_strobe_i : std_logic;
    signal data_override_o : std_logic_vector(575 downto 0);
    signal tb_match_idx_o : integer;
    signal tb_is_match_o : std_logic;
    signal ram_write_err_flag_o : std_logic;
    signal data_vector_ready_o : std_logic;
    signal fi_frame_ready_o : std_logic;
    signal axi_interrupt_resp_i : std_logic;
    signal interrupt_req_i : std_logic;
    signal interrupt_o : std_logic;


    type data_vector_array_t is array (0 to 15) of std_logic_vector(575 downto 0);
    constant data_vector_array : data_vector_array_t := (
        0  => x"7646ba1ca6e2dd6251462d91141542057c18876f420158c55e107748a1cdaa223c5ddfd919877d953dca06230733bc7552b5d2d8149e2e399c557904c571cc27f966e24d00000000",
        1  => x"c52d4bbb58d117e36f2c1edb868785e6fc43022797b09db0cf63842312b16a94bb06b3471215fa5b9f82ceeb1159ffb4e5a8f403661adec5cb08e05934cbc28ea8b80ee500000000",
        2  => x"57af995386d1bebe7cb75e6773c071b556469b5c1f1df561870e1755490961eadd7b2540e4e74af5fd1afb94ef5a1aa7f4c2cd93840dd71017f47c499dd3b8a6592dbd4900000000",
        3  => x"9b0611819fa77ccb1bec6c5ef310f6a0f24954af5044525a7a7b0d1dd097bba1973ee411b10a3149c3f8524612f0d77d7cfe65227be5f4924ca2d02c2dc3df3864ec486c00000000",
        4  => x"1650e9fd0fc13ca9dd2d4477243a07cc97ded9e8061f801501f89e579163a4ee33b029cb238a52eb83e935debb19234147432f0b853f563e82d13fd23c7cf1999f6f376b00000000",
        5  => x"5310fafeb85fa67e19352bb1a8f944b1e5071f5349cd708afef79595317b32c56fe423555a89f395b7c9bf0d65498b1c6d0ef87c6b92fff33e6e829a7a72d022774b053f00000000",
        6  => x"ebf9bbb7b51984329e34fa2c9cacfbbb895e70c8021b0102ed48eec4e40629391d969a89f4f581a68650160484faed18e39b6c56a1d28203a7b71e1fc7676761dedd435e00000000",
        7  => x"3c336c84e688a5b4736bd7e1ef33f387e1572378ffc5c62bf66dccf444d6f9da3a0d15e7ee005fcac4cffc2a110cba4a205fe1defb1de9ce250b9f5f9657ca7ac11ac63e00000000",
        8  => x"7c55f428b09a65932b1fefff63ce9c77b76af2636a02b32d8eef1038e3008d6e07af2b408d431943a9d5dc3d5d120860eb7b12fec8f5db963fc37aa1b1fbf9059a9af98f00000000",
        9  => x"eb5bac174e9dfa608171c8409e852e942186f4a79ea3feddf3556a8fdcee931edcd510b5bcf6066e38f37e40ac30a76159aa4439d3e8582bb08d67cfa75dc7dab1d8b79c00000000",
        10 => x"fe85f7c40aeec2642bdf90fff5b2b4fa2196cc5761e9ce96140203a2099212ea21c43ef2398d2b7a09283ab569bc3b9f18ba725c9f7dc07e33274025f5da78d2a132e32600000000",
        11 => x"d11c030a774edccdf039f49b7e0d6e4d18b6d00290705c2b627d1d464b0155237ba4c0119957cd1a4be0dae0c79eef4df291ffdb0970930a5dbc4a4e8983024a063cd34700000000",
        12 => x"f6d64ce6a5a70b9aeb396532c07d0ff1aedf353344fe24de24f13800361044e7e81b7891726a6ae25bd9dda7c2ca5702ec41ea38f2d7382a40937863b56fde43eafbe15a00000000",
        13 => x"4fae36051e71ed87fae164f0e2bad25878abce77390baf9c3a2043251faa8aa35f4512ab8b152a483597cb8eb03ab8a424d33d7b4c6f4256ffd34b3d4cb71f5026dfd75c00000000",
        14 => x"f6693bf59303caf20326669bf586248ea37e63b20914373648e3c7a1920a84e36644b0371f648dc344a013f2c4c0e880d4e8a52a6fe66c6d097927afc202fc7d2ccf050e00000000",
        15 => x"6587c3f8e6d76b316d828dd7e20526927a3a260b394a2a20eac35f77c199b805e03126e782209bacd66d31fefab607cdc49af1bed63100eaef8314dbc08e8bf50302da8b00000000"
    );


    constant id_mem_arr : id_mem_arr_t(0 to 15) := (
        0  => (id_value => "01101011001011101000110100101", id_mask => "10101010101010101010101010101", fi_frame => (FI_DATA, "000", "000001111")),
        1  => (id_value => "10100101110001101011010110101", id_mask => "11111000001111100000111110000", fi_frame => (FI_DATA, "000", "000001111")),
        2  => (id_value => "00011101011011010101000111111", id_mask => "00000000000000000000000000000", fi_frame => (FI_DATA, "000", "000001111")),
        3  => (id_value => "11010111011000101101011110001", id_mask => "11111111111111111111111100000", fi_frame => (FI_DATA, "000", "000001111")),
        4  => (id_value => "01011011010101110110101011010", id_mask => "00000000000000000000000000000", fi_frame => (FI_DATA, "000", "000001111")),
        5  => (id_value => "00110011010101101110101101011", id_mask => "00000000011111111110000000000", fi_frame => (FI_DATA, "000", "000001111")),
        6  => (id_value => "11101011010100111101010101101", id_mask => "10010010010010010010010010010", fi_frame => (FI_DATA, "000", "000001111")),
        7  => (id_value => "01010101110101011011010101011", id_mask => "00000000000000000000000000000", fi_frame => (FI_DATA, "000", "000001111")),
        8  => (id_value => "10111010101101010110101110101", id_mask => "11001100110011001100110011001", fi_frame => (FI_DATA, "000", "000001111")),
        9  => (id_value => "01110101101110101011010101011", id_mask => "00110011001100110011001100110", fi_frame => (FI_DATA, "000", "000001111")),
        10 => (id_value => "00011101011011010101110101011", id_mask => "00000000000000000000000000000", fi_frame => (FI_DATA, "000", "000001111")),
        11 => (id_value => "11010101101101010111010101101", id_mask => "00000000000000000000000000000", fi_frame => (FI_DATA, "000", "000001111")),
        12 => (id_value => "01011011010101110110101011011", id_mask => "00000000000000000000000000000", fi_frame => (FI_DATA, "000", "000001111")),
        13 => (id_value => "00110011010101101110101101101", id_mask => "00000000000000000000000000000", fi_frame => (FI_DATA, "000", "000001111")),
        14 => (id_value => "11101011010100111101010101110", id_mask => "00000000000000000000000000000", fi_frame => (FI_DATA, "000", "000001111")),
        15 => (id_value => "01010101110101011011010101111", id_mask => "11111111110000000000111111111", fi_frame => (FI_DATA, "000", "000001111"))
    );


begin

    memory_unit_inst : entity work.memory_unit
    generic map (
        ID_MEM_ENTRY_COUNT => ID_MEM_ENTRY_COUNT
    )
    port map (
        clk => clk,
        reset_n => reset_n,
        sleep_i => sleep_i,
        cfg_en_i => cfg_en_i,
        axi_id_mem_arr_i => axi_id_mem_arr_i,
        bus_id_buffer_i => bus_id_buffer_i,
        bus_id_buffer_ready_i => bus_id_buffer_ready_i,
        fi_frame_o => fi_frame_o,
        axi_data_valid_i => axi_data_valid_i,
        axi_data_addr_i => axi_data_addr_i,
        axi_data_payload_i => axi_data_payload_i,
        axi_data_strobe_i => axi_data_strobe_i,
        data_override_o => data_override_o,
        tb_tree_is_match_o => tb_is_match_o,
        tb_match_idx_o => tb_match_idx_o,
        ram_write_err_flag_o => ram_write_err_flag_o,
        fi_frame_ready_o => fi_frame_ready_o,
        data_vector_ready_o => data_vector_ready_o,
        axi_interrupt_resp_i => axi_interrupt_resp_i,
        interrupt_req_i => interrupt_req_i,
        interrupt_o => interrupt_o
    );

    clk <= not clk after clk_period/2;

    axi_id_mem_arr_i <= id_mem_arr(0 to ID_MEM_ENTRY_COUNT - 1); 


    main_tb : process
    begin
        sleep_i <= '1';
        reset_n <= '0';
        wait for clk_period;
        reset_n <= '1';
        
        -- TEST 1. Check Matching and correct access 
        -- Assignment Phase

        -- set to configuration state
        cfg_en_i <= '1';
        sleep_i <= '1';
        wait for clk_period;

        for i in 0 to ID_MEM_ENTRY_COUNT - 1 loop

            for j in 0 to 17 loop
                -- set AXI registers
                axi_data_valid_i <= '1';
                axi_data_addr_i <= std_logic_vector(to_unsigned((i * 32) + j, 15)); 
                axi_data_payload_i <= data_vector_array(i)((j * 32) + 31 downto (j * 32));
                axi_data_strobe_i <= '1';
                wait for clk_period;
                assert ram_write_err_flag_o = '0' report "RAM write error flag was raised on index i=" & integer'image(i) & " j=" & integer'image(j) severity failure; 
            end loop;
            
            axi_data_valid_i <= '0';
            axi_data_strobe_i <= '0';
            wait for clk_period;
        end loop;

        -- Retrieval Phase
        cfg_en_i <= '0';
        wait for clk_period;

        for i in 0 to ID_MEM_ENTRY_COUNT - 1 loop
            
            sleep_i <= '0';
            bus_id_buffer_ready_i <= '0';
            wait for clk_period;

            bus_id_buffer_i <= id_mem_arr(i).id_value;
            bus_id_buffer_ready_i <= '1';
            -- Tree Prop time + RAM Delay
            wait for clk_period * ((log2_ceil(ID_MEM_ENTRY_COUNT) + 1) + 3 + 1); 

            assert fi_frame_o = id_mem_arr(i).fi_frame report "FI Frame of Vector " & integer'image(i) & " does not match!" severity failure;
            assert data_override_o = data_vector_array(i) report "Data Override Vector " & integer'image(i) & " does not match!" severity failure;
            wait for clk_period;
            sleep_i <= '1';
            wait for clk_period;

            
        end loop;

        report "Finished Test 1";
        
        -- Test 2. Test Boundary writes to RAM

        -- set to configuration state
        cfg_en_i <= '1';
        sleep_i <= '1';
        wait for clk_period;
        
        -- Write Valid Vectors
        for i in 0 to ID_MEM_ENTRY_COUNT - 1 loop

            for j in 0 to 17 loop
                -- set AXI registers
                axi_data_valid_i <= '1';
                axi_data_addr_i <= std_logic_vector(to_unsigned((i * 32) + j, 15)); 
                axi_data_payload_i <= data_vector_array(i)((j * 32) + 31 downto (j * 32));
                axi_data_strobe_i <= '1';
                wait for clk_period;
                assert ram_write_err_flag_o = '0' report "RAM write error flag was raised on index i=" & integer'image(i) & " j=" & integer'image(j) severity failure; 
            end loop;
            
            axi_data_valid_i <= '0';
            axi_data_strobe_i <= '0';
            wait for clk_period;
        end loop;


        -- Write to the padded portion. Each entry occupies a 32-segment stride
        -- but only segments 0..17 are valid; segments 18..31 are padding that
        -- exists only to satisfy the power-of-two read-width ratio, and writes
        -- into them must raise the error flag.
        for i in 0 to ID_MEM_ENTRY_COUNT - 1 loop
            for j in 18 to 31 loop
                axi_data_valid_i <= '1';
                axi_data_addr_i <= std_logic_vector(to_unsigned((i * 32) + j, 15));
                axi_data_payload_i <= x"FFFFFFFF";
                axi_data_strobe_i <= '1';
                wait for clk_period;
                assert ram_write_err_flag_o = '1' report "RAM write error flag was NOT raised on padded segment i=" & integer'image(i) & " j=" & integer'image(j) severity failure;
            end loop;

            axi_data_valid_i <= '0';
            axi_data_strobe_i <= '0';
            wait for clk_period;
        end loop;

        -- Write to out of bounds region
        axi_data_valid_i <= '1';
        axi_data_addr_i <= "111" & x"FFF"; 
        axi_data_payload_i <= x"AFFEAFFE";
        axi_data_strobe_i <= '1';
        wait for clk_period;
        assert ram_write_err_flag_o = '1' report "RAM write error flag was NOT raised on write to 0xFFFFFFFF" severity failure; 
            
        axi_data_valid_i <= '0';
        axi_data_strobe_i <= '0';
        wait for clk_period;
        

        -- Test Data Integrity

        -- Retrieval Phase
        cfg_en_i <= '0';
        wait for clk_period;
        for i in 0 to ID_MEM_ENTRY_COUNT - 1 loop
            sleep_i <= '0';
            bus_id_buffer_ready_i <= '0';
            wait for clk_period;

            bus_id_buffer_i <= id_mem_arr(i).id_value;
            bus_id_buffer_ready_i <= '1';
            -- Tree Prop time + RAM Delay
            wait for clk_period * ((log2_ceil(ID_MEM_ENTRY_COUNT) + 1) + 3); 

            assert data_override_o = data_vector_array(i) report "Data Override Vector " & integer'image(i) & " does not match!" severity failure; 
            wait for clk_period;
            sleep_i <= '1';
            wait for clk_period;
            
        end loop;

        axi_data_valid_i <= '0';
        axi_data_strobe_i <= '0';
        wait for clk_period;

        report "Finished Test 2";

        -- TEST 3. Check assignment on invalid flags
        -- cfg_en off, sleep on
        -- Expected Behavior: RAM Should not be written to, FI Frames should not be parsed
        -- cfg_en on, sleep on
        -- Expected Behavior: RAM Should be written to, Fi Frame should not be parsed
        -- cfg_en on, sleep off -> Impossible state, as sleep is contolled by TU and cfg_on requires sleep off
        for i in 0 to 1 loop
            
            reset_n <= '0';
            wait for clk_period;
            reset_n <= '1';
            wait for clk_period;

            cfg_en_i <= '0' when i = 0 else '1';
            sleep_i <=  '1';
            wait for clk_period;

            -- Attempt to set Registers
            for i in 0 to ID_MEM_ENTRY_COUNT - 1 loop
                for j in 0 to 17 loop
                    -- set AXI registers
                    axi_data_valid_i <= '1';
                    axi_data_addr_i <= std_logic_vector(to_unsigned((i * 32) + j, 15)); 
                    axi_data_payload_i <= data_vector_array(i)((j * 32) + 31 downto (j * 32));
                    axi_data_strobe_i <= '1';
                    wait for clk_period;
                end loop;
                
                axi_data_valid_i <= '0';
                axi_data_strobe_i <= '0';
                wait for clk_period;
            end loop;

            -- Retrieval Phase
            for i in 0 to ID_MEM_ENTRY_COUNT - 1 loop
                
                bus_id_buffer_ready_i <= '0';
                wait for clk_period;

                bus_id_buffer_i <= id_mem_arr(i).id_value;
                bus_id_buffer_ready_i <= '1';

                -- Tree Prop time + RAM Delay
                wait for clk_period * ((log2_ceil(ID_MEM_ENTRY_COUNT) + 1) + 3); 

                assert fi_frame_o = fi_frame_init report "FI Frame of Vector " & integer'image(i) & " got loaded with invalid setting!" severity failure;
                assert data_override_o = (575 downto 0 => '0')  report "Data Override Vector " & integer'image(i) & " got loaded with invalid setting!" severity failure; 
                wait for clk_period;
                sleep_i <= '1';
                wait for clk_period;

                
            end loop;

        end loop;


        -- Test Interrupt
        wait for clk_period;
        interrupt_req_i <= '1';
        wait for clk_period;
        assert interrupt_o = '1' report "Interrupt did not trigger" severity failure;
        interrupt_req_i <= '0';
        wait for clk_period;
        assert interrupt_o = '1' report "Interrupt did not hold" severity failure;
        axi_interrupt_resp_i <= '1';
        wait for clk_period;
        assert interrupt_o = '0' report "Interrupt did not reset" severity failure;


        assert False report "All tests passed successfully!" severity failure;

    end process;


end;