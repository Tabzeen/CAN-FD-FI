
import random
from canhack.canframe import CANFrame
from canhack.canfdframe import CANFDFrame


###
# NOTE: Extended Classes and Formatting outputs were partially generated using a LLM

# NOTE 2: We cannot use basic interitance, as both CANFrame and CANFDFrame are two seperate classes, therfore we have a lot of redundancies
###

import random
from canhack.canframe import CANFrame
from canhack.canfdframe import CANFDFrame

class ExtCANFrame(CANFrame):
    def __init__(self, *args, max_data_bits=64, max_raw_bits=128, **kwargs):
        super().__init__(*args, **kwargs)
        self.max_data_bits = max_data_bits
        self.max_raw_bits = max_raw_bits


    def get_is_fd(self):
        return False 

    def get_str_id(self):
        if self.ide:
            id_a = self.fields.get('ida', '0' * 11)
            id_b = self.fields.get('idb', '0' * 18)
            return f'"{id_a}{id_b}"'
        else:
            id_a = self.fields.get('ida', '0' * 11)
            id_a = id_a.rjust(29, "0")
            return f'"{id_a}"'

    def get_str_dlc(self):
        dlc_mapping = [0, 1, 2, 3, 4, 5, 6, 7, 8, 12, 16, 20, 24, 32, 48, 64]
        
        # self.dlc contains the raw byte length from the base class
        dlc_code = dlc_mapping.index(self.dlc)
        return f"{dlc_code:04b}"

    def get_str_ctrl(self):
        r0 = self.fields.get('r0', '0')
        r1 = self.fields.get('r1', '0')
        return f"{r0}{r1}00"

    def get_str_data(self):
        return self.fields.get('data', '')
    
    def get_str_data_hex(self):
        data_bits = self.fields.get('data', '')
        if not data_bits:
            return "(others => '0')"

        pad_length = self.max_data_bits
        padded_data = data_bits.rjust(pad_length, '0')
        hex_val = f"{int(padded_data, 2):0{pad_length // 4}X}"
        return f'x"{hex_val}"'

    def get_data_len(self):
        data_bits = self.fields.get('data', '')
        return len(data_bits) 

    def get_str_crc_stf(self):
        return "0000"

    def get_str_crc(self):
        crc_bits = self.fields.get('crc', f"{self._crc_rg:015b}")
        return crc_bits.rjust(21, '0')

    def get_str_crc_raw(self):
        crc_bits = self.fields.get('crc', f"{self._crc_rg}")
        return crc_bits

    def get_str_eof(self):
        """Returns bits from CRC Delimiter to the end of the frame (IFS)"""
        crc_del = self.fields.get('crc_delimiter', '1')
        ack = self.fields.get('ack', '0')
        ack_del = self.fields.get('ack_delimiter', '1')
        eof = self.fields.get('eof', '1111111')
        ifs = self.fields.get('ifs', '111')
        return f"{crc_del}{ack}{ack_del}{eof}{ifs}"

    def get_raw_frame_data(self):
        bitseq = self.bitseq()
        raw_frame_len = len(bitseq)
        pad_length = max(self.max_raw_bits, ((raw_frame_len + 3) // 4) * 4)
        padded_bitseq = bitseq.ljust(pad_length, '0')
        raw_frame_hex = f"{int(padded_bitseq, 2):0{pad_length//4}X}"
        return raw_frame_hex, raw_frame_len

    def format_record(self, index=0):
        raw_frame_hex, raw_frame_len = self.get_raw_frame_data()
        
        return (
            f"        {index} => (\n"
            f"            id            => {self.get_str_id()},\n"
            f"            dlc           => \"{self.get_str_dlc()}\",\n"
            f"            ctrl          => \"{self.get_str_ctrl()}\",\n"
            f"            data          => {self.get_str_data_hex()},\n"
            f"            data_len      => {self.get_data_len()},\n"
            f"            crc_stf       => \"{self.get_str_crc_stf()}\",\n"
            f"            crc           => \"{self.get_str_crc()}\",\n"
            f"            eof           => \"{self.get_str_eof()}\",\n"
            f"            raw_frame     => x\"{raw_frame_hex}\",\n"
            f"            raw_frame_len => {raw_frame_len}\n"
            f"        )"
        )
    
    def get_stuff_indices_by_group(self):
        """
        Returns a dictionary mapping each user-defined field group 
        to a list of local indices where stuff bits occur, relative to the start of the group.
        """
        import re
        
        # Tokenize bitstream by ANSI escape codes to accurately track color state per bit
        tokens = re.split(r'(\x1b\[\d+m)', self.stuffed_bitstream)
        
        stuff_indices = []
        bit_idx = 0
        in_red = False
        
        for token in tokens:
            if not token:
                continue
            if token.startswith('\x1b['):
                if token == self.RED:
                    in_red = True
                elif token == self.RESET:
                    in_red = False
            else:
                # Parse actual bit characters
                for char in token:
                    if char in ('0', '1'):
                        if in_red:
                            stuff_indices.append((bit_idx, char))
                        bit_idx += 1

        # Map fields to groups. 
        # rtr is CAN 2.0, rrs is CAN FD. 
        group_mapping = {
            'sof': 'id', 'ida': 'id', 'idb': 'id',
            'srr': 'ignored', 'ide': 'ignored', 'rtr': 'ignored', 'rrs': 'ignored',
            'r1': 'ctrl', 'r0': 'ctrl',
            'fdf': 'ctrl', 'res': 'ctrl', 'brs': 'ctrl', 'esi': 'ctrl',
            'dlc': 'dlc',
            'data': 'data',
            'crc': 'crc',
            'crc_delimiter': 'eof', 'ack': 'eof', 'ack_delimiter': 'eof', 'eof': 'eof', 'ifs': 'eof'
        }

        # Calculate the start index for each group to compute local offsets
        group_starts = {}
        for base_field, bit_range in self.fields_position.items():
            group = group_mapping.get(base_field)
            if group and bit_range:
                if group not in group_starts:
                    group_starts[group] = bit_range.start
                else:
                    group_starts[group] = min(group_starts[group], bit_range.start)

        result = { 'id': [], 'ctrl': [], 'dlc': [], 'data': [], 'crc': [], 'eof': [] }

        for idx, bit_val in stuff_indices:
            for base_field, bit_range in self.fields_position.items():
                if idx in bit_range:
                    group = group_mapping.get(base_field)
                    if group and group in result:
                        local_offset = idx - group_starts[group]
                        result[group].append((local_offset, bit_val))
                    break

        return result


class ExtCANFDFrame(CANFDFrame):
    def __init__(self, *args, max_data_bits=512, max_raw_bits=128, **kwargs):
        super().__init__(*args, **kwargs)
        self.max_data_bits = max_data_bits
        self.max_raw_bits = max_raw_bits

    def _to_bitstream(self):
        """
        Overrides CANFDFrame._to_bitstream to prevent double-stuffing at the 
        boundary between dynamically stuffed fields (Data) and the fixed-stuffed CRC field.
        """
        DLC_MAP = [0, 1, 2, 3, 4, 5, 6, 7, 8, 12, 16, 20, 24, 32, 48, 64]
        STUFFBIT_COUNT_CODING = [0x0, 0x03, 0x6, 0x05, 0xc, 0xf, 0xa, 0x9]

        self.fields = {
            'sof': '0',
            'rrs': '1' if self.rrs else '0',
            'fdf': '1' if self.fdf else '0',
            'res': '0',
            'brs': '1' if self.brs else '0',
            'esi': '1' if self.esi else '0',
            'dlc': "{:04b}".format(DLC_MAP.index(self.dlc)),
            'data': "".join(["{:08b}".format(byte) for byte in self.data]),
            'crc_delimiter': '1',
            'ack': '1' if self.ack == 1 else '0',
            'ack_delimiter': '1',
            'eof': '1111111',
            'ifs': '111'
        }

        if self.ide:
            self.fields['ida'] = "{:011b}".format(self.id_a)
            self.fields['srr'] = '1'
            self.fields['ide'] = '1'
            self.fields['idb'] = "{:018b}".format(self.id_b)
            self.fieldnames = ['sof', 'ida', 'srr', 'ide', 'idb', 'rrs']
        else:
            self.fields['ida'] = "{:011b}".format(self.id_a)
            self.fields['ide'] = '0'
            self.fieldnames = ['sof', 'ida', 'rrs', 'ide']
            
        self.fieldnames += ['fdf', 'res', 'brs', 'esi', 'dlc', 'data', 'crc', 'crc_delimiter', 'ack', 'ack_delimiter', 'eof', 'ifs']

        # Count total bits in dynamically stuffed fields to identify the boundary
        stuffed_bit_count = 0
        for fieldname in self.fieldnames:
            if fieldname == 'crc':
                break
            if fieldname in self.STUFFED_FIELDS:
                stuffed_bit_count += len(self.fields[fieldname])

        processed_stuffed_bits = 0

        for fieldname in self.fieldnames:
            start = len(self.frame_bits)

            if fieldname == 'crc':
                _crc_unstuffed_bitstream = "{:04b}".format(STUFFBIT_COUNT_CODING[self._stuff_bit_count])
                for bit in range(0, len(_crc_unstuffed_bitstream)):
                    self._calc_crc(_crc_unstuffed_bitstream[bit])

                if len(self.data) <= 16:
                    _crc_unstuffed_bitstream += "{:017b}".format(self._crc_rg)
                else:
                    _crc_unstuffed_bitstream += "{:021b}".format(self._crc_rg)

                self.unstuffed_bitstream += _crc_unstuffed_bitstream

                _crc_stuffed_bitstream = self._add_fixed_stuff_bits(_crc_unstuffed_bitstream)
                self.stuffed_bitstream += _crc_stuffed_bitstream

            else:
                color = self.FIELD_COLORS[fieldname]
                stuffed = fieldname in self.STUFFED_FIELDS

                self.fields_position[fieldname] = [len(self.frame_bits), 0]
                for bit in self.fields[fieldname]:
                    self.unstuffed_bitstream += color + bit + self.RESET
                    self.stuffed_bitstream += color + bit + self.RESET
                    self.frame_bits.append(True if bit == '1' else False)
                    
                    if stuffed:
                        processed_stuffed_bits += 1
                        self._calc_crc(bit=bit)
                        
                        # Inline stuff bit tracking to allow boundary suppression
                        if bit == '0':
                            self._0_bits_in_row += 1
                            self._1_bits_in_row = 0
                        else:
                            self._1_bits_in_row += 1
                            self._0_bits_in_row = 0

                        is_last_stuffed_bit = (processed_stuffed_bits == stuffed_bit_count)

                        if self._0_bits_in_row == 5:
                            if not is_last_stuffed_bit:
                                self.frame_bits.append(True)
                                self._calc_crc(bit='1')
                                self.stuffed_bitstream += self.RED + '1' + self.RESET
                                self._1_bits_in_row = 1
                                self._0_bits_in_row = 0
                                self._stuff_bit_count = (self._stuff_bit_count + 1) % 8
                        if self._1_bits_in_row == 5:
                            if not is_last_stuffed_bit:
                                self.frame_bits.append(False)
                                self._calc_crc(bit='0')
                                self.stuffed_bitstream += self.RED + '0' + self.RESET
                                self._0_bits_in_row = 1
                                self._1_bits_in_row = 0
                                self._stuff_bit_count = (self._stuff_bit_count + 1) % 8

            self.fields_position[fieldname] = range(start, len(self.frame_bits))

    def get_is_fd(self):
        return True

    def get_str_id(self):
        if self.ide:
            id_a = self.fields.get('ida', '0' * 11)
            id_b = self.fields.get('idb', '0' * 18)
            return f'"{id_a}{id_b}"'
        else:
            id_a = self.fields.get('ida', '0' * 11)
            id_a = id_a.rjust(29, "0")
            return f'"{id_a}"'

    def get_str_dlc(self):
        dlc_mapping = [0, 1, 2, 3, 4, 5, 6, 7, 8, 12, 16, 20, 24, 32, 48, 64]
        
        # self.dlc contains the raw byte length from the base class
        dlc_code = dlc_mapping.index(self.dlc)
        return f"{dlc_code:04b}"

    def get_str_ctrl(self):
        fdf = self.fields.get('fdf', '0')
        res = self.fields.get('res', '0')
        brs = self.fields.get('brs', '0')
        esi = self.fields.get('esi', '0')
        return f"{fdf}{res}{brs}{esi}"

    def get_str_data(self):
        return self.fields.get('data', '')
    
    def get_str_data_hex(self):
        data_bits = self.fields.get('data', '')
        if not data_bits:
            return "(others => '0')"
        
        pad_length = self.max_data_bits
        padded_data = data_bits.rjust(pad_length, '0')
        hex_val = f"{int(padded_data, 2):0{pad_length // 4}X}"
        return f'x"{hex_val}"'

    def get_data_len(self):
        data_bits = self.fields.get('data', '')
        return len(data_bits) 

    def get_str_crc_stf(self):
        stf_coding = [0x0, 0x03, 0x6, 0x05, 0xc, 0xf, 0xa, 0x9]
        return f"{stf_coding[self._stuff_bit_count]:04b}"

    def get_str_crc(self):
        crc_len = 17 if len(self.data) <= 16 else 21
        crc_bits = f"{self._crc_rg:0{crc_len}b}"
        return crc_bits.rjust(21, '0')

    def get_str_crc_raw(self):
        if len(self.data) <= 16:
            return f"{self._crc_rg:017b}"
        else:
            return f"{self._crc_rg:021b}"
    
    def get_str_eof(self):
        """Returns bits from CRC Delimiter to the end of the frame (IFS)"""
        crc_del = self.fields.get('crc_delimiter', '1')
        ack = self.fields.get('ack', '0')
        ack_del = self.fields.get('ack_delimiter', '1')
        eof = self.fields.get('eof', '1111111')
        ifs = self.fields.get('ifs', '111')
        return f"{crc_del}{ack}{ack_del}{eof}{ifs}"

    def get_raw_frame_data(self):
        bitseq = self.bitseq()
        raw_frame_len = len(bitseq)
        pad_length = max(self.max_raw_bits, ((raw_frame_len + 3) // 4) * 4)
        padded_bitseq = bitseq.ljust(pad_length, '0')
        raw_frame_hex = f"{int(padded_bitseq, 2):0{pad_length//4}X}"
        return raw_frame_hex, raw_frame_len

    def format_record(self, index=0):
        raw_frame_hex, raw_frame_len = self.get_raw_frame_data()
        
        return (
            f"        {index} => (\n"
            f"            id            => {self.get_str_id()},\n"
            f"            dlc           => \"{self.get_str_dlc()}\",\n"
            f"            ctrl          => \"{self.get_str_ctrl()}\",\n"
            f"            data          => {self.get_str_data_hex()},\n"
            f"            data_len      => {self.get_data_len()},\n"
            f"            crc_stf       => \"{self.get_str_crc_stf()}\",\n"
            f"            crc           => \"{self.get_str_crc()}\",\n"
            f"            eof           => \"{self.get_str_eof()}\",\n"
            f"            raw_frame     => x\"{raw_frame_hex}\",\n"
            f"            raw_frame_len => {raw_frame_len}\n"
            f"        )"
        )
    
    def get_stuff_indices_by_group(self):
        """
        Returns a dictionary mapping each user-defined field group 
        to a list of local indices where stuff bits occur, relative to the start of the group.
        """
        import re
        
        # Tokenize bitstream by ANSI escape codes to accurately track color state per bit
        tokens = re.split(r'(\x1b\[\d+m)', self.stuffed_bitstream)
        
        stuff_indices = []
        bit_idx = 0
        in_red = False
        
        for token in tokens:
            if not token:
                continue
            if token.startswith('\x1b['):
                if token == self.RED:
                    in_red = True
                elif token == self.RESET:
                    in_red = False
            else:
                # Parse actual bit characters
                for char in token:
                    if char in ('0', '1'):
                        if in_red:
                            stuff_indices.append((bit_idx, char))
                        bit_idx += 1

        # Map fields to groups. 
        group_mapping = {
            'sof': 'id', 'ida': 'id', 'idb': 'id',
            'srr': 'ignored', 'ide': 'ignored', 'rtr': 'ignored', 'rrs': 'ignored',
            'r1': 'ctrl', 'r0': 'ctrl',
            'fdf': 'ctrl', 'res': 'ctrl', 'brs': 'ctrl', 'esi': 'ctrl',
            'dlc': 'dlc',
            'data': 'data',
            'crc': 'crc',  # Unified CRC
            'crc_delimiter': 'eof', 'ack': 'eof', 'ack_delimiter': 'eof', 'eof': 'eof', 'ifs': 'eof'
        }

        # Calculate the start index for each group to compute local offsets
        group_starts = {}
        for base_field, bit_range in self.fields_position.items():
            group = group_mapping.get(base_field)
            if group and bit_range:
                if group not in group_starts:
                    group_starts[group] = bit_range.start
                else:
                    group_starts[group] = min(group_starts[group], bit_range.start)

        # Initialize results with the unified 'crc' key
        result = { 'id': [], 'ctrl': [], 'dlc': [], 'data': [], 'crc': [], 'eof': [] }

        for idx, bit_val in stuff_indices:
            # Standard field processing for all bits (including CRC)
            for base_field, bit_range in self.fields_position.items():
                if idx in bit_range:
                    group = group_mapping.get(base_field)
                    if group and group in result:
                        local_offset = idx - group_starts[group]
                        result[group].append((local_offset, bit_val))
                    break

        return result


class FIErr:
    NONE = "000"
    BIT = "100"
    DOM = "010"
    DLC = "001"
class FIFrame:


    # Corespondance map from encoded field value to the readable key value
    FI_FIELD_KEY_MAP = dict(zip([f"{x:03b}" for x in range(7)], ["id", "ctrl", "dlc", "data", "crc_stf", "crc", "eof"])) 
        

    # Maps each type of fi map to field values compatible with the error type
    FI_TYPE_FIELD_MAP = {
        "FI_DATA": ["000"],
        "FI_BSDY": [f"{x:03b}" for x in [1, 3, 5]], 
        "FI_BSFX": ["101"],
        "FI_DLC" : ["000"],
        "FI_BIT": [f"{x:03b}" for x in [1, 3, 5, 6]], 
        "FI_NULL": ["000"]
    }






    def __init__(self, frame_id, can_frame, fi_type: str, fi_err : str, target_frame_idx : int, max_data_crc_bits = 64):
        self.fi_type = fi_type
        # Field and Meta is randomly generated down the line, depending on the used type
        # HACK: Remove the Data field from the pool if the DLC is 0x0
        available_fields = self.FI_TYPE_FIELD_MAP[fi_type]
        if can_frame.fields["dlc"] == "0000" and "011" in available_fields:
            available_fields.remove("011")
        self.fi_field = random.choice(available_fields) 
        self.fi_meta = "000000000"
        self.fi_valid = int(fi_err == "000")
        self.fi_err = fi_err

        self.max_data_crc_bits = max_data_crc_bits
        self.data_crc_override = ["1"] * max_data_crc_bits

        self.target_frame_idx = target_frame_idx

        self.can_frame_data_len = can_frame.get_data_len()

        self.can_frame = can_frame
        self.frame_id = frame_id

        match self.fi_err:
            # No issues, create a working frame
            case FIErr.NONE:
                match self.fi_type:
                    case "FI_DATA":
                        self.fi_meta = "00000" + can_frame.get_str_dlc() 
                        # Uniformly Select a random subset of bits which we want to override
                        can_data_crc = self._build_data_crc_vector()
                        ones_idx = [i for i, bit in enumerate(can_data_crc) if bit == "1"]
                        # Force at least one override, if none happen, we still have a valid override
                        if ones_idx:
                            self.data_crc_override[random.choice(ones_idx)] = "0"

                        for i in ones_idx:
                            if random.randint(0, 1):
                                self.data_crc_override[i] = "0" 
                            
                    case "FI_BSDY" | "FI_BSFX" :
                        # Extract stuffing bit positions in raw frame
                        stuff_idx_dict = can_frame.get_stuff_indices_by_group()
                        stuff_key = self.FI_FIELD_KEY_MAP[self.fi_field]
                        stuff_list = stuff_idx_dict[stuff_key]
                        
                        recessive_idx = [i for i, (offset, bit_val) in enumerate(stuff_list) if bit_val == "1"]

                        if recessive_idx: 
                            meta_val = random.choice(recessive_idx)
                            self.fi_meta = f"{meta_val:09b}"

                        # Frame has no recessive stuffing, change to bit not found error   
                        else:
                            self.fi_err = "100"
                            self.fi_meta = "111111111"
                        # Change to bit not found error, as BSDY cannot override BSFX Bits
                        if self.fi_type == "FI_BSDY" and can_frame.get_is_fd() and self.fi_field == "101": 
                            self.fi_err = "100"
                        print("#############################") 
                        print("FI Frame IDX", self.frame_id)
                        can_frame.print()
                        print("Recessive IDX", recessive_idx)
                        print("Err T", self.fi_type)
                        print("Target Erf", self.fi_err)
                        print("Target Field", self.fi_field)
                        print("Is FD", can_frame.get_is_fd())
                        print("CRC_STF", can_frame.get_str_crc_stf())
                        print("CRC", can_frame.get_str_crc())
                        print("#############################") 

                    case "FI_DLC":
                        # generate override dlc, which is compatible with the frame
                        ov_dlc = "".join(["0" if x == "1" else "1" for x in can_frame.get_str_dlc()]) 
                        self.fi_meta = "00000" + ov_dlc
                    case "FI_BIT":
                        target_bits = ""
                        # select a bit index which is overridable
                        field_key = self.FI_FIELD_KEY_MAP[self.fi_field]
                        match field_key:
                            # TODO: Add a working ID case 
                            case "id":
                                target_bits = can_frame.get_str_id()
                            case "ctrl":
                                target_bits = can_frame.get_str_ctrl()
                            case "eof":
                                # HACK: Dont use the IFS
                                target_bits = can_frame.get_str_eof()[:9]
                            case "crc":
                                target_bits = can_frame.get_str_crc_raw()
                            case "data":
                                target_bits = can_frame.get_str_data()
                            case _:
                                raise ValueError("Invalid field setting for bit error")
                        valid_idx = [i for i, val in enumerate(target_bits) if val == "1"]
                        # HACK Exclude the SOF
                        if field_key == 'id' and valid_idx == 0:
                            valid_idx +=1    
                        if not can_frame.get_is_fd():
                            # Filter out FD Indices
                            valid_idx = [x for x in valid_idx if x not in [2,3]]
                            # Filter out Ext ID indices:
                            if can_frame.ide == 0:
                                valid_idx = [x for x in valid_idx if x != 1]

                        if valid_idx:
                            meta_val = random.choice(valid_idx) 
                            self.fi_meta = f"{meta_val:09b}"
                        # If no valid bit was found, change to "already dominant" error and choose the first one 
                        else: 
                            self.fi_meta = "000000000"
                            self.fi_err = "010"
                        print("#############################") 
                        print("FI Frame IDX", self.frame_id)
                        can_frame.print()
                        print("Valid IDX", valid_idx)
                        print("Targeted Bits", target_bits)
                        print("Err T", self.fi_type)
                        print("Target Erf", self.fi_err)
                        print("Target Field", self.fi_field)
                        print("Is FD", can_frame.get_is_fd())
                        print("CRC_STF", can_frame.get_str_crc_stf())
                        print("CRC", can_frame.get_str_crc())
                        print("#############################") 
                    case "FI_NULL":
                        pass

            # Bit not encountered error, create an inaccessable index for the requested set meta field 
            case FIErr.BIT:
                match self.fi_type:
                    case "FI_DATA":
                        raise ValueError("Incompatible error type for data, use DLC missmatch error instead")
                    case "FI_BSDY" | "FI_BSFX" :
                        self.fi_meta = "111111111"
                    case "FI_DLC":
                        raise ValueError("Incompatible error type for DLC")
                    case "FI_BIT":
                        self.fi_meta = "111111111"
                    case "FI_NULL":
                        pass

            # Bit was already dominant, select an index offset which is dominant for the meta field 
            case FIErr.DOM:
                match self.fi_type:
                    case "FI_DATA":
                        self.fi_meta = "00000" + can_frame.get_str_dlc()
                        # Uniformly Select a random subset of bits which we want to override
                        can_data_crc = self._build_data_crc_vector()
                        zeroes_idx = [i for i, bit in enumerate(can_data_crc) if bit == "0"]
                        # Force at least one override
                        if zeroes_idx:
                            self.data_crc_override[random.choice(zeroes_idx)] = "0"

                        for i in zeroes_idx:
                            if random.randint(0, 1):
                                self.data_crc_override[i] = "0" 

                    case "FI_BSDY" | "FI_BSFX" :


                        stuff_idx_dict = can_frame.get_stuff_indices_by_group()
                        stuff_key = self.FI_FIELD_KEY_MAP[self.fi_field]
                        stuff_list = stuff_idx_dict[stuff_key]
                        
                        dominant_idx = [i for i, (offset, bit_val) in enumerate(stuff_list) if bit_val == "0"]

                        if dominant_idx: 
                            meta_val = random.choice(dominant_idx)
                            self.fi_meta = f"{meta_val:09b}"
                        else:
                            print("Frame has no dominant stuffing, change to bit not found error")
                            self.fi_err = "100"
                            self.fi_meta = "111111111"
                        if self.fi_type == "FI_BSDY" and can_frame.get_is_fd() and self.fi_field == "101": 
                            print("Changed to bit not found error, as BSDY cannot override BSFX Bits")
                            self.fi_err = "100"
                        print("#############################") 
                        print("FI Frame IDX", self.frame_id)
                        can_frame.print()
                        print("Recessive IDX", dominant_idx)
                        print("Err T", self.fi_type)
                        print("Target Erf", self.fi_err)
                        print("Target Field", self.fi_field)
                        print("Is FD", can_frame.get_is_fd())
                        print("CRC_STF", can_frame.get_str_crc_stf())
                        print("CRC", can_frame.get_str_crc())
                        print("#############################") 

                    case "FI_DLC":
                        # Just provide the exact same dlc, this will try to override the first 0
                        # and in addition the tb override buffer wont complain as it will assemble the undistrubed dlc of the initial frame
                        frame_dlc = can_frame.get_str_dlc()
                        ov_dlc = (["0"] * 5) + list(frame_dlc)
                        self.fi_meta = "".join(ov_dlc)
                    case "FI_BIT":
                        target_bits = ""
                        field_key = self.FI_FIELD_KEY_MAP[self.fi_field]
                        match field_key:
                            # TODO: Add a working ID case 
                            case "id":
                                target_bits = can_frame.get_str_id()
                            case "ctrl":
                                target_bits = can_frame.get_str_ctrl()
                            case "eof":
                                # HACK: Dont use the IFS
                                target_bits = can_frame.get_str_eof()[:10]
                            case "crc":
                                target_bits = can_frame.get_str_crc_raw()
                            case "data":
                                target_bits = can_frame.get_str_data()
                            case _:
                                raise ValueError("Invalid field setting for bit error")
                        valid_idx = [i for i, val in enumerate(target_bits) if val == "0"]
                        if field_key == 'id' and valid_idx == 0:
                            valid_idx +=1    

                        ## Filter out non ID Indices
                        if not can_frame.get_is_fd():
                            # Filter out Idx of FD bits like FDF, R1 etc
                            valid_idx = [x for x in valid_idx if x not in [2,3]]
                            # Filter out the R1 which comes with an extended bit
                            if can_frame.ide == 0:
                                valid_idx = [x for x in valid_idx if x != 1]

                        if valid_idx:
                            meta_val = random.choice(valid_idx)
                            self.fi_meta = f"{meta_val:09b}"
                        # If no valid bit was found, change to "valid err" error and choose tne first one 
                        else: 
                            self.fi_meta = "000000000"
                            self.fi_err = "000"

                        print("#############################") 
                        print("FI Frame IDX", self.frame_id)
                        can_frame.print()
                        print("Valid IDX", valid_idx)
                        print("Targeted Bits", target_bits)
                        print("Err T", self.fi_type)
                        print("Target Erf", self.fi_err)
                        print("Target Field", self.fi_field)
                        print("Is FD", can_frame.get_is_fd())
                        print("CRC_STF", can_frame.get_str_crc_stf())
                        print("CRC", can_frame.get_str_crc())
                        print("#############################") 
                    case "FI_NULL":
                        pass

            # DLC doesnt match, generate a dlc meta which is not equal to the test frame dlc
            case FIErr.DLC:
                if self.fi_type != "FI_DATA":
                    raise ValueError("Cannot produce DLC Error if FI-Type is not FI_DATA")
                
                rdm_dlc = random.getrandbits(4)
                # Thats some amazing 2AM coding right here
                self.fi_meta = f"{(rdm_dlc if rdm_dlc != int(can_frame.get_str_dlc(), 2) else (rdm_dlc + 1) % 0x10):09b}"
                

    def _build_data_crc_vector(self):
        can_data = self.can_frame.get_str_data()[:self.can_frame_data_len]
        can_crc_stf = self.can_frame.get_str_crc_stf()
        can_crc = self.can_frame.get_str_crc()

        data_crc_stream = can_data
        # Include stuff into stream only if fd vector
        if self.can_frame.get_is_fd():
            data_crc_stream += can_crc_stf
        
            if len(can_data) <= 128:
                data_crc_stream += can_crc[-17:]
            else:
                data_crc_stream += can_crc
        else:
            data_crc_stream += can_crc[-15:]
            
        return data_crc_stream


    def _gen_exp_data(self):

        if self.fi_type != "FI_DATA" or self.fi_err == "001":
            return "".join(["0"] * (self.max_data_crc_bits // 4))

        can_seq = self._build_data_crc_vector()
        cut_idx = len(can_seq)


        for i in range(len(can_seq)):
            if can_seq[i] == '0' and self.data_crc_override[i] == '0':
                cut_idx = i
                break

        cut_bits = "".join(self.data_crc_override[:cut_idx])

        pad_length = self.max_data_crc_bits
        padded_bits = cut_bits.ljust(pad_length, '0')

        val = int(padded_bits, 2) if padded_bits.strip() else 0
        hex_str = f"{val:0{pad_length // 4}X}"

        return hex_str
    
    def get_str_type(self):
        return self.fi_type

    def get_str_field(self):
        return self.fi_field 

    def get_str_meta(self):
        return self.fi_meta 

    def get_str_valid(self):
        return self.fi_valid
    

    def get_raw_frame_data(self):
        data_crc_length = len(self._build_data_crc_vector())
        bitseq = "".join(self.data_crc_override)[:data_crc_length]
        raw_data_len = len(bitseq)
        pad_length = max(self.max_data_crc_bits, ((raw_data_len + 3) // 4) * 4)
        padded_bitseq = bitseq.ljust(pad_length, '0')
        raw_frame_hex = f"{int(padded_bitseq, 2):0{pad_length//4}X}"
        return raw_frame_hex, raw_data_len

    def format_record(self, index = 0):
        raw_data_hex, raw_data_len = self.get_raw_frame_data()
        return (
            f"        {index} => (\n"
            f"            fi_type  => {self.get_str_type()},\n"
            f"            fi_field => \"{self.get_str_field()}\",\n"
            f"            fi_meta  => \"{self.get_str_meta()}\",\n"
            f"            fi_valid => \'{self.get_str_valid()}\',\n"
            f"            fi_err => \"{self.fi_err}\",\n"
            f"            fi_data_vec => x\"{raw_data_hex}\",\n"
            f"            fi_data_len => {raw_data_len},\n"
            f"            fi_gt_data_out => x\"{self._gen_exp_data()}\",\n"
            f"            fi_target_frame_idx => {self.target_frame_idx}\n"
            f"        )"
        )


