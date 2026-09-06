
LOOPBACK_GLOBAL = False 

PORT_MAP_CFG = [0, 7, 4, 0, 0, 0, 0, 0]
PORT_MAP_CFG_DISABLE = [0, 0, 4, 0, 0, 0, 0, 0]

SPEED_PROFILES = {
    "250K": {
        "API": {
            "bit_timing": {"bitrate": 250000, "sample_point": 0.8},
            "bring_up": True,
            "control_modes": {"Fd": False, "Loopback": LOOPBACK_GLOBAL},
        },
        "FI": {
            "nomi": {
                "bitrate": 250,
                "brp_core": 3,
                "psp_frac": 0.60,
                "fip_frac": 0.60,
            }
        },
    },
    "500K": {
        "API": {
            "bit_timing": {"bitrate": 500000, "sample_point": 0.8},
            "bring_up": True,
            "control_modes": {"Fd": False, "Loopback": LOOPBACK_GLOBAL},
        },
        "FI": {
            "nomi": {
                "bitrate": 500,
                "brp_core": 2,
                "psp_frac": 0.61,
                "fip_frac": 0.61,
            }
        },
    },
    "500K_FD": {
        "API": {
            "bit_timing": {"bitrate": 500000, "sample_point": 0.8},
            "bring_up": True,
            "control_modes": {"Fd": True, "Loopback": LOOPBACK_GLOBAL},
            "data_bit_timing": {"bitrate": 500000, "sample_point": 0.8 },
        },
        "FI": {
            "nomi": {
                "bitrate": 500,
                "brp_core": 2,
                "psp_frac": 0.4,
                "fip_frac": 0.4,
            },
            "data": {
                "bitrate": 500,
                "brp_core": 2,
                "psp_frac": 0.65,
                "fip_frac": 0.65,
            },
        },
    },
    "1M": {
        "break" : True,
        "API": {
            "bit_timing": {"bitrate": 1000000, "sample_point": 0.8},
            "bring_up": True,
            "control_modes": {"Fd": False, "Loopback": LOOPBACK_GLOBAL},
        },
        "FI": {
            "nomi": {
                "bitrate": 1000,
                "brp_core": 1,
                "psp_frac": 0.41,
                "fip_frac": 0.41,
            }
        },
    },
    "1M_FD": {
        "API": {
            "bit_timing": {"bitrate": 500000, "sample_point": 0.8},
            "bring_up": True,
            "control_modes": {"Fd": True, "Loopback": LOOPBACK_GLOBAL},
            "data_bit_timing": {"bitrate": 1000000, "sample_point": 0.8},
        },
        "FI": {
            "nomi": {
                "bitrate": 500,
                "brp_core": 4,
                "psp_frac": 0.4,
                "fip_frac": 0.4,
            },
            "data": {
                "bitrate": 1000,
                "brp_core": 1,
                "psp_frac": 0.53,
                "fip_frac": 0.53,
            },
        },
    },
    # Max limit given the loop delay for multi-bit injections
    "1_2M_FD": {
        "API": {
            "bit_timing": {"bitrate": 500000, "sample_point": 0.8},
            "bring_up": True,
            "control_modes": {"Fd": True, "Loopback": LOOPBACK_GLOBAL},
            "data_bit_timing": {"bitrate": 1200000, "sample_point": 0.8},
        },
        "FI": {
            "nomi": {
                "bitrate": 500,
                "brp_core": 2,
                "psp_frac": 0.6,
                "fip_frac": 0.6,
            },
            "data": {
                "bitrate": 1200,
                "brp_core": 1,
                "psp_frac": 0.40,
                "fip_frac": 0.40,
            },
        },
    },
    "1_5M_FD": {
        "API": {
            "bit_timing": {"bitrate": 500000, "sample_point": 0.8},
            "bring_up": True,
            "control_modes": {"Fd": True, "Loopback": LOOPBACK_GLOBAL},
            "data_bit_timing": {"bitrate": 1500000, "sample_point": 0.8},
        },
        "FI": {
            "nomi": {
                "bitrate": 500,
                "brp_core": 4,
                "psp_frac": 0.6,
                "fip_frac": 0.6,
            },
            "data": {
                "bitrate": 1500,
                "brp_core": 1,
                "psp_frac": 0.42,
                "fip_frac": 0.42,
            },
        },
    },
    "2M_FD": {
        "API": {
            "bit_timing": {"bitrate": 500000, "sample_point": 0.8},
            "bring_up": True,
            "control_modes": {"Fd": True, "Loopback": LOOPBACK_GLOBAL},
            "data_bit_timing": {"bitrate": 2000000, "sample_point": 0.8},
        },
        "FI": {
            "nomi": {
                "bitrate": 500,
                "brp_core": 4,
                "psp_frac": 0.6,
                "fip_frac": 0.6,
            },
            "data": {
                "bitrate": 2000,
                "brp_core": 1,
                "psp_frac": 0.30,
                "fip_frac": 0.30,
            },
        },
    },
    # MAX LIMIT given the loop delay for single bit injections
    "2_1M_FD": {
        "API": {
            "bit_timing": {"bitrate": 500000, "sample_point": 0.8},
            "bring_up": True,
            "control_modes": {"Fd": True, "Loopback": LOOPBACK_GLOBAL},
            "data_bit_timing": {"bitrate": 2100000, "sample_point": 0.8},
        },
        "FI": {
            "nomi": {
                "bitrate": 500,
                "brp_core": 4,
                "psp_frac": 0.4,
                "fip_frac": 0.4,
            },
            "data": {
                "bitrate": 2100,
                "brp_core": 1,
                "psp_frac": 0.41,
                "fip_frac": 0.41,
            },
        },
    },
}



ERR_PROFILES_API = [
    {
        "state" : "ErrorActive"
    },
    {
        "state" : "ErrorPassive"
    } 
]

FI_TYPES_IDX_MAP = {
    "FI_BIT" : 0,
    "FI_BSDY" : 0,
    "FI_BSFX": 0,
    "FI_DLC": 0,
    "FI_DATA_CRC": 0
}

FI_TYPES_ERR_MAP = {
    "FI_BIT" : 0,
    "FI_BSDY" : 0,
    "FI_BSFX": 0,
    "FI_DLC": 1,
    "FI_DATA_CRC": 1
}

# 0001 1010 1010
FRAME_PROFILES_RECORD_TEST = {
    "FI_BIT": [
        {
            # Bit before is Dominaint
            "fd_only": False,
            "can_frame": {
                "id": {"base": 0x5A4, "extended": None},
                "data": [0x1A, 0xAB]
            },
            "fi_frames": [
                {
                    "id": "0x5A4",
                    "id_mask": "0x0000000",
                    "type": "bit",
                    "field": "data",
                    "meta": "10", 
                    "err": "none"
                },
                {
                    "id": "0x5A4",
                    "id_mask": "0x0000000",
                    "type": "bit",
                    "field": "ctrl",
                    "meta": "0", 
                    "err": "inj_dom"
                },
            ]    
        },
        {
            # Bit before is Recessive 
            "fd_only": False,
            "can_frame": {
                "id": {"base": 0x5A4, "extended": None},
                "data": [0x1A, 0xEB]
            },
            "fi_frames": [
                {
                    "id": "0x5A4",
                    "id_mask": "0x0000000",
                    "type": "bit",
                    "field": "data",
                    "meta": "10", 
                    "err": "none"
                },
                {
                    "id": "0x5A4",
                    "id_mask": "0x0000000",
                    "type": "bit",
                    "field": "ctrl",
                    "meta": "0", 
                    "err": "inj_dom"
                },
            ]    
        },
        {
            "fd_only": False,
            "can_frame": {
                "id": {"base": 0x5A4, "extended": None},
                "data": [0x10, 0xF0, 0xAA, 0x7E, 0xFF, 0x3B, 0x12, 0x89]
            },
            "fi_frames": [
                # Targetting the first bit of the 0xFF segment
                # Pass: 25k
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                {
                    "break" : True,
                    "id": "0x5A4",
                    "id_mask": "0x0000000",
                    "type": "bit",
                    "field": "data",
                    "meta": "8", 
                    "err": "none"
                },
            ],
        }
    

        
        ],
    "FI_DLC": [
        # Bit Override Transition Point last bit Dominant
        {
            "fd_only" : False,
            # DLC 0110
            "can_frame": {
                "id": {"base": 0x634, "extended": None},
                "data": [
                    0x80, 0xAA, 0x1A, 0x1A, 0xBA, 0xAA  
                ]
            },
            "fi_frames": [
                {
                    "id": "0x634",
                    "id_mask": "0x0000000",
                    "type": "dlc",
                    "field": "",
                    "meta": "0xA", 
                    "err": "none"
                },
            ] 
        },
        # Bit Override Transition Point last bit Recessive
        {
            "fd_only" : False,
            # DLC 0110
            "can_frame": {
                "id": {"base": 0x634, "extended": None},
                "data": [
                    0x80, 0xAA, 0x1A, 0x1A, 0xBA, 0xAA  
                ]
            },
            "fi_frames": [
                {
                    "id": "0x634",
                    "id_mask": "0x0000000",
                    "type": "dlc",
                    "field": "",
                    "meta": "0xD", 
                    "err": "none"
                },
            ] 
        },
        {
            "fd_only" : False,
            # DLC 0110
            "can_frame": {
                "id": {"base": 0x6AF, "extended": None},
                "data": [
                    0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6
                ]
            },
            "fi_frames": [
                {
                    "id": "0x6AF",
                    "id_mask": "0x0000000",
                    "type": "dlc",
                    "field": "",
                    "meta": "0x8", 
                    "err": "none"
                },
            ] 
        },

    ],
    "FI_DATA_CRC": [
        {
            # Testing For Base Frame
            "fd_only" : False,
            "can_frame": {
                "id": {"base": 0x0A5, "extended": None},
                "data": [
                    0x5A, 0x6D 
                ]
            },
            "fi_frames": [
                {
                    # Valid CRC
                    "id": "0x0A5",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0x2", 
                    "err": "none",
                    "data_vec": "8A0FF34BFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
                },
                {
                    # Invalid CRC
                    "id": "0x0A5",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0x2", 
                    "err": "none",
                    "data_vec": "8A0F254BFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
                },
            ] 
        },
        {
            "fd_only" : True,
            # DLC 1000
            "can_frame": {
                "id": {"base": 0x0A5, "extended": None},
                "data": [
                    0x5A, 0x6D 
                ]
            },
            "fi_frames": [
                {
                    "break" : True,
                    # FD Matching CRC
                    "id": "0x0A5",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0x2", 
                    "err": "none",
                    "data_vec": "8AFF6744FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
                },
                {
                    # FD Non matching CRC
                    "id": "0x0A5",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0x2", 
                    "err": "none",
                    "data_vec": "8AFF254BFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
                },
            ] 
        },
        {
            # Large Vector Test
            # IT WORKS!
            "fd_only" : True,
            "can_frame": {
                "id": {"base": 0x280, "extended": None},
                "data" : [26, 195, 79, 130, 157, 94, 11, 119, 52, 145, 250, 98, 24, 231, 92, 160, 43, 109, 142, 19, 71, 251, 144, 82, 62, 140, 113, 6, 223, 165, 36, 153, 255, 74, 189, 115, 12, 229, 47, 136, 27, 148, 87, 192, 110, 61, 130, 15, 68, 123, 33, 214, 137, 48, 175, 88, 18, 103, 158, 60, 133, 234, 64, 179]

            },
            "fi_frames": [
                {
                    "id": "0x280",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0xF", 
                    "err": "none",
                    # Creates valid CRC Data override
                    #"data_vec": "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00A2CB445F3188D6770E992ABC5163FA38CD1F487095E20B558AD96C143EA1FE" + "C9C054F"
                    'data_vec':  "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00A2CB445F3188D6770E992ABC5163FA38CD1F487095E20B558AD96C143EA1FEC9C054FFFFFFFFFF"
                },
                {
                    "id": "0x280",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0xF", 
                    "err": "inj_dlc",
                    # Same but Invalid CRC 
                    'data_vec':  "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00A2CB445F3188D6770E992ABC5163FA38CD1F487095E20B558AD96C143EA1FEC9C154FFFFFFFFFF"
                },
                {
                    "id": "0x280",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0x3", 
                    "err": "none",
                    # Invalid DLC
                    "data_vec": "FFFFFF700B773491FA6218E75CA02B6D8E1347FB90523E8C7106DFA52499614ABD730CE52F881B9457C06E3D820F447B21D68930AF5812679E3C85EA40B317A372"
                },
            ] 
        },
        {
            # Getting the CRC bits. Merged Data with override Vector 
            # Original Vector is:
            # [26,  195,  79, 130, 157,  94,  11, 119,  52, 145, 250,  98,  24, 231,  92, 160,  43, 109, 142,  19,  71, 251, 144,  82,  62, 140, 113,   6, 223, 165,  36, 153, 255, 74, 189, 115, 12, 229, 47, 136, 27, 148, 87, 192, 110, 61, 130, 15, 68, 123, 33, 214, 137, 48, 175, 88, 18, 103, 158, 60, 133, 234, 64, 179]
            # Override Vector
            # [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0, 162, 203, 68, 95, 49, 136, 214, 119, 14, 153, 42, 188, 81, 99, 250, 56, 205, 31, 72, 112, 149, 226, 11, 85, 138, 217, 108, 20, 62, 161, 254]
            # [26,  195,  79, 130, 157,  94,  11, 119,  52, 145, 250,  98,  24, 231,  92, 160,  43, 109, 142,  19,  71, 251, 144,  82,  62, 140, 113,   6, 223, 165,  36, 153, 0, 162, 203, 68, 95, 49, 136, 214, 119, 14, 153, 42, 188, 81, 99, 250, 56, 205, 31, 72, 112, 149, 226, 11, 85, 138, 217, 108, 20, 62, 161, 254]

            "fd_only" : True,
            "can_frame": {
                "id": {"base": 0x280, "extended": None},
                # Combined Vector
                "data" : [26, 195, 79, 130, 157, 94, 11, 119, 52, 145, 250, 98, 24, 231, 92, 160, 43, 109, 142, 19, 71, 251, 144, 82, 62, 140, 113, 6, 223, 165, 36, 153, 0, 162, 203, 68, 95, 49, 136, 214, 119, 14, 153, 42, 188, 81, 99, 250, 56, 205, 31, 72, 112, 149, 226, 11, 85, 138, 217, 108, 20, 62, 161, 254]
            },
            "fi_frames": [
                {
                    "id": "0x281",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0xF", 
                    "err": "none",
                    "data_vec": "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00A2CB445F3188D6770E992ABC5163FA38CD1F487095E20B558AD96C143EA1FE"
                },
            ] 
        },
    ]
}

FRAME_PROFILES = {
    "FI_BIT": [
        {
            "fd_only": False,
            "can_frame": {
                "id": {"base": 0x5A4, "extended": None},
                "data": [0xAA, 0xAA, 0xAA, 0x7E, 0xFF, 0x3B, 0x12, 0x89]
            },
            "fi_frames": [
                # Targetting the first bit of the 0xFF segment
                # Pass: 25k
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                {
                    "id": "0x5A4",
                    "id_mask": "0x0000000",
                    "type": "bit",
                    "field": "data",
                    "meta": "8", 
                    "err": "none"
                },
                {
                # Pass: 25k
                # Pass: 1M (Produces no err in FD)
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x5A4",
                    "id_mask": "0x0000000",
                    "type": "bit",
                    "field": "ctrl",
                    "meta": "0", 
                    "err": "inj_dom"
                },
                {
                # Pass: 25k
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x5A4",
                    "id_mask": "0x0000000",
                    "type": "bit",
                    "field": "data",
                    "meta": "64", 
                    "err": "inj_miss"
                }
            
            ]    
        },
        {
            "fd_only" : True,
            "can_frame": {
                "id": {"base": 0x3A4, "extended": None},
                "data": [
                    0x55, 0xAA, 0x33, 0xCC, 0x0F, 0xF0, 0x7B, 0x1C,
                    0xE4, 0x2D, 0x98, 0x6A, 0xB3, 0x4F, 0x11, 0x8E
                ]
            },
            "fi_frames": [
                # Targetting the very first bit that is targetable, which is the fdf bit
                {
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x3A4",
                    "id_mask": "0x0000000",
                    "type": "bit",
                    "field": "ctrl",
                    "meta": "0", 
                    "err": "none"
                },
                # Targetting the BRS Bit
                {
                # Pass: 1M
                # Pass: 2M
                # Pass (Somewhat, 1.3 M CRC Error)
                # Pass: 2.1M
                    "id": "0x3A4",
                    "id_mask": "0x0000000",
                    "type": "bit",
                    "field": "ctrl",
                    "meta": "2", 
                    "err": "none"
                },
                # Targetting the CRC DEL Bit
                {
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x3A4",
                    "id_mask": "0x0000000",
                    "type": "bit",
                    "field": "eof",
                    "meta": "0", 
                    "err": "none"
                },
                # Targetting the very last bit targetable
                {
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # NO PASS at 2.1M
                # at 2.1 the override is perceived as an overload frame
                    "break" : True,
                    "id": "0x3A4",
                    "id_mask": "0x0000000",
                    "type": "bit",
                    "field": "eof",
                    "meta": "8", 
                    "err": "none"
                }
            ]
        },
        {
            "fd_only" : True,
            "can_frame": {
                "id": {"base": 0x199, "extended": None},
                "data":[
                    0x8F, 0x1C, 0xA3, 0x5D, 0xE2, 0x48, 0x7B, 0x09,
                    0xD4, 0x6E, 0x17, 0xB0, 0x3F, 0x92, 0x55, 0xC8,
                    0x71, 0xAA, 0x43, 0xF9, 0x0D, 0x86, 0x2E, 0x5B,
                    0x9C, 0x30, 0xE7, 0x64, 0x18, 0xBF, 0x52, 0xDB,
                    0x4A, 0x83, 0xCD, 0x21, 0xF6, 0x7E, 0x05, 0x98,
                    0x3D, 0xB4, 0x69, 0x12, 0xAE, 0x57, 0xC0, 0x8B,
                    0xF1, 0x29, 0x74, 0x0C, 0x9E, 0x63, 0xDA, 0x45,
                    0x58, 0xCF, 0x82, 0x1B, 0x37, 0xEA, 0x7D, 0xFF
                ]
            },
            "fi_frames": [
                # Targetting the first stuffed bit of the data segment, should produce an inj_dom err
                {
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x199",
                    "id_mask": "0x0000000",
                    "type": "bit",
                    "field": "data",
                    "meta": "511", 
                    "err": "none"
                },
            ]
        },
        {
            "fd_only": False,
            "can_frame": {
                "id": {"base": 0x3BB, "extended": None},
                "data": [0xDE, 0xBF, 0xBE, 0xEF]
            },
            "fi_frames": [
                {
                # Pass: 25k
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x3BB",
                    "id_mask": "0x0000000",
                    "type": "bit",
                    "field": "data",
                    "meta": "31", 
                    "err": "none"
                },
                # Targeting the first CRC bit
                # Pass: 25k
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                {
                    "id": "0x3BB",
                    "id_mask": "0x0000000",
                    "type": "bit",
                    "field": "crc",
                    "meta": "0", 
                    "err": "none"
                }
            ]

        }
    ],
    
    "FI_BSDY": [
        {
            "fd_only": False,
            "can_frame": {
                "id": {"base": 0x14F, "extended": None},
                "data": [0x3F, 0x47, 0xC0, 0x0D, 0x55, 0xAA, 0x6C, 0x93]
            },
            "fi_frames": [
                # Targetting the second stuffed bit of the data segment, should produce no error 
                {
                # Pass: 25k
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x14F",
                    "id_mask": "0x000000F",
                    "type": "dyn-stuff",
                    "field": "data",
                    "meta": "0", 
                    "err": "none",
                },
                # Targetting the first stuffed bit of the data segment, should produce an inj_dom err
                {
                # Pass: 25k
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x14F",
                    "id_mask": "0x000000F",
                    "type": "dyn-stuff",
                    "field": "data",
                    "meta": "1", 
                    "err": "inj_dom"
                },
                # Targetting a stuffing bit which doesnt exist, should produe a miss error
                {
                # Pass: 25k
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x14F",
                    "id_mask": "0x000000F",
                    "type": "dyn-stuff",
                    "field": "data",
                    "meta": "7", 
                    "err": "inj_miss"
                }
            
            ]    
        },
        {
            "fd_only" : True,
            "can_frame": {
                "id": {"base": 0x148, "extended": None},
                "data":[
                    0x3E, 0x00, 0x4D, 0x72, 0xB5, 0x1A, 0x6E, 0x9B,
                    0x2D, 0x53, 0xA9, 0x4B, 0xD6, 0x35, 0x9C, 0x6A,
                    0x59, 0x26, 0xD4, 0xAB, 0x75, 0x1D, 0x63, 0x8E,
                    0x5A, 0x9D, 0x36, 0x4E, 0xB2, 0xCD, 0x56, 0x9A,
                    0x65, 0x3B, 0xD2, 0x4F, 0x26, 0x8D, 0x69, 0xB4,
                    0x5E, 0x2A, 0x93, 0xC5, 0x6B, 0xD1, 0x4A, 0x79,
                    0x2E, 0x5D, 0xB6, 0x8B, 0x4D, 0x3A, 0x6C, 0x95,
                    0x2B, 0xD4, 0x6E, 0xAB, 0x53, 0x9C, 0x6A, 0xC2
                ]
            },
            "fi_frames": [
                # Targetting the first stuffed bit of the data segment, should produce an inj_dom err
                {
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x148",
                    "id_mask": "0x0000000",
                    "type": "dyn-stuff",
                    "field": "data",
                    "meta": "0", 
                    "err": "inj_dom"
                },
                # Targetting the second stuffed bit of the data segment, should produce no error 
                {
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x148",
                    "id_mask": "0x0000000",
                    "type": "dyn-stuff",
                    "field": "data",
                    "meta": "1", 
                    "err": "none"
                },
                # Targetting a stuffing bit which doesnt exist, should produe a miss error
                {
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x148",
                    "id_mask": "0x0000000",
                    "type": "dyn-stuff",
                    "field": "data",
                    "meta": "3", 
                    "err": "inj_miss"
                }
            
            ] 
        },
        {
            "fd_only": False,
            "can_frame": {
                "id": {"base": 0x31F, "extended": None},
                "data": []
            },
            "fi_frames": [
                # Targetting the stuffing between the arbit and ctrl section
                {
                # Pass: 1M (No Stuff in FD)
                # Pass: 25k
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x31F",
                    "id_mask": "0x0000000",
                    "type": "dyn-stuff",
                    "field": "ctrl",
                    "meta": "0", 
                    "err": "none",
                },
            ]

        }
    ],
    "FI_BSFX": [
        {
            "fd_only" : True,
            "can_frame": {
                "id": {"base": 0x1FF, "extended": None},
                "data": [
                    0x65, 0x3B, 0xD2, 0x4F, 0x26, 0x8D, 0x69, 0xB4,
                    0x5E, 0x2A, 0x93, 0xC5, 0x6B, 0xD1, 0x4A, 0x79,
                    0x2E, 0x5D, 0xB6, 0x8B, 0x4D, 0x3A, 0x6C, 0x95,
                    0x2B, 0xD4, 0x6E, 0xAB, 0x53, 0x9C, 0x6A, 0xC2
                ]
            },
            "fi_frames": [
                # Targetting the first CRC stuff which must be a 1
                {
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x1FF",
                    "id_mask": "0x0000000",
                    "type": "fix-stuff",
                    "field": "crc-stf",
                    "meta": "0", 
                    "err": "none"
                },
                # Targetting a stuff bit that doesnt exist
                {
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x1F0",
                    "id_mask": "0x0000000",
                    "type": "fix-stuff",
                    "field": "crc-stf",
                    "meta": "3", 
                    "err": "inj_miss"
                },
                # Targetting a stuff bit in the CRC section
                {
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x1FF",
                    "id_mask": "0x000000F",
                    "type": "fix-stuff",
                    "field": "crc",
                    "meta": "3", 
                    "err": "inj_miss"
                }
            
            ] 
        },
    ],
    "FI_DLC": [
        {
            "fd_only" : False,
            # DLC 1000
            "can_frame": {
                "id": {"base": 0x636, "extended": None},
                "data": [
                    0x10, 0x22, 0x34, 0x46, 0x58, 0x6A, 0x7C, 0x8E
                ]
            },
            "fi_frames": [
                {
                # Pass: 25k
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x636",
                    "id_mask": "0x0000000",
                    "type": "dlc",
                    "field": "",
                    "meta": "0x2", 
                    "err": "none"
                },
            ] 
        },
        {
            "fd_only" : True,
            # DLC 1100
            "can_frame": {
                "id": {"base": 0x636, "extended": None},
                "data": [
                    0x3F, 0xA1, 0x8C, 0x05, 0xDE, 0x72, 0x9B, 0x44,
                    0x1E, 0x88, 0xFA, 0x2D, 0x5C, 0x09, 0x6E, 0xB7,
                    0x4A, 0x13, 0xD0, 0x8F, 0x22, 0x6B, 0xE4, 0x51
                ]
            },
            "fi_frames": [
                {
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x636",
                    "id_mask": "0x0000000",
                    "type": "dlc",
                    "field": "",
                    "meta": "0xB", 
                    "err": "none"
                },
                {
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x636",
                    "id_mask": "0x0000000",
                    "type": "dlc",
                    "field": "",
                    "meta": "0xC", 
                    "err": "inj_dom"
                },
            ] 
        },
        {
            "fd_only" : False,
            # DLC 0110
            "can_frame": {
                "id": {"base": 0x636, "extended": None},
                "data": [
                    0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6
                ]
            },
            "fi_frames": [
                {
                # Pass: 25k
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x636",
                    "id_mask": "0x0000000",
                    "type": "dlc",
                    "field": "",
                    "meta": "0xB", 
                    "err": "none"
                },
                {
                # Pass: 25k
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x636",
                    "id_mask": "0x0000000",
                    "type": "dlc",
                    "field": "",
                    "meta": "0xE", 
                    "err": "inj_dom"
                },
            ] 
        },
        # We want a stuff after the first Injection so the DLC should barely not be stuffed
        # 0 DLC0 + 0 IDE + 0 RTR + r0 0 -> 0xF ID => 4 0 bits
        {
            "fd_only" : False,
            # DLC 0110
            "can_frame": {
                "id": {"base": 0x6AF, "extended": None},
                "data": [
                    0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6
                ]
            },
            "fi_frames": [
                {
                # Pass: 25k
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x6AF",
                    "id_mask": "0x0000000",
                    "type": "dlc",
                    "field": "",
                    "meta": "0xC", 
                    "err": "none"
                },
            ] 
        },
        # We want a stuff before the first Injection, so we shift the thing from above to the left, ie ID = 0xE
        {
            "fd_only" : False,
            # DLC 0110
            "can_frame": {
                "id": {"base": 0x6AE, "extended": None},
                "data": [
                    0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6
                ]
            },
            "fi_frames": [
                {
                # Pass: 25k
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x6AE",
                    "id_mask": "0x0000000",
                    "type": "dlc",
                    "field": "",
                    "meta": "0xC", 
                    "err": "none"
                },
            ] 
        },
        {
            "fd_only" : False,
            # DLC 0000
            "can_frame": {
                "id": {"base": 0x636, "extended": None},
                "data": []
            },
            "fi_frames": [
                {
                # Pass: 25k
                # Pass: 1M
                # Pass: 1.3M
                # Pass: 2M
                # Pass: 2.1M
                    "id": "0x636",
                    "id_mask": "0x0000000",
                    "type": "dlc",
                    "field": "",
                    "meta": "0x0", 
                    "err": "inj_dom"
                },
            ] 
        },
    ],
    "FI_DATA_CRC": [
        {
            # Testing For Base Frame
            "fd_only" : False,
            "can_frame": {
                "id": {"base": 0x0A5, "extended": None},
                "data": [
                    0x5A, 0x6D 
                ]
            },
            "fi_frames": [
                {
                    # Valid CRC
                    "id": "0x0A5",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0x2", 
                    "err": "none",
                    "data_vec": "8A0FF34BFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
                },
                {
                    # Invalid CRC
                    "id": "0x0A5",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0x2", 
                    "err": "none",
                    "data_vec": "8A0F254BFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
                },
            ] 
        },
        {
            "fd_only" : True,
            # DLC 1000
            "can_frame": {
                "id": {"base": 0x0A5, "extended": None},
                "data": [
                    0x5A, 0x6D 
                ]
            },
            "fi_frames": [
                {
                    # FD Matching CRC
                    "id": "0x0A5",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0x2", 
                    "err": "none",
                    "data_vec": "8AFF6744FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
                },
                {
                    # FD Non matching CRC
                    "id": "0x0A5",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0x2", 
                    "err": "none",
                    "data_vec": "8AFF254BFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
                },
            ] 
        },
        {
            # Large Vector Test
            # IT WORKS!
            "fd_only" : True,
            "can_frame": {
                "id": {"base": 0x280, "extended": None},
                "data" : [26, 195, 79, 130, 157, 94, 11, 119, 52, 145, 250, 98, 24, 231, 92, 160, 43, 109, 142, 19, 71, 251, 144, 82, 62, 140, 113, 6, 223, 165, 36, 153, 255, 74, 189, 115, 12, 229, 47, 136, 27, 148, 87, 192, 110, 61, 130, 15, 68, 123, 33, 214, 137, 48, 175, 88, 18, 103, 158, 60, 133, 234, 64, 179]

            },
            "fi_frames": [
                {
                    "id": "0x280",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0xF", 
                    "err": "none",
                    # Creates valid CRC Data override
                    #"data_vec": "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00A2CB445F3188D6770E992ABC5163FA38CD1F487095E20B558AD96C143EA1FE" + "C9C054F"
                    'data_vec':  "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00A2CB445F3188D6770E992ABC5163FA38CD1F487095E20B558AD96C143EA1FEC9C054FFFFFFFFFF"
                },
                {
                    "id": "0x280",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0xF", 
                    "err": "inj_dlc",
                    # Same but Invalid CRC 
                    'data_vec':  "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00A2CB445F3188D6770E992ABC5163FA38CD1F487095E20B558AD96C143EA1FEC9C154FFFFFFFFFF"
                },
                {
                    "id": "0x280",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0x3", 
                    "err": "none",
                    # Invalid DLC
                    "data_vec": "FFFFFF700B773491FA6218E75CA02B6D8E1347FB90523E8C7106DFA52499614ABD730CE52F881B9457C06E3D820F447B21D68930AF5812679E3C85EA40B317A372"
                },
            ] 
        },
        {
            # Getting the CRC bits. Merged Data with override Vector 
            # Original Vector is:
            # [26,  195,  79, 130, 157,  94,  11, 119,  52, 145, 250,  98,  24, 231,  92, 160,  43, 109, 142,  19,  71, 251, 144,  82,  62, 140, 113,   6, 223, 165,  36, 153, 255, 74, 189, 115, 12, 229, 47, 136, 27, 148, 87, 192, 110, 61, 130, 15, 68, 123, 33, 214, 137, 48, 175, 88, 18, 103, 158, 60, 133, 234, 64, 179]
            # Override Vector
            # [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0, 162, 203, 68, 95, 49, 136, 214, 119, 14, 153, 42, 188, 81, 99, 250, 56, 205, 31, 72, 112, 149, 226, 11, 85, 138, 217, 108, 20, 62, 161, 254]
            # [26,  195,  79, 130, 157,  94,  11, 119,  52, 145, 250,  98,  24, 231,  92, 160,  43, 109, 142,  19,  71, 251, 144,  82,  62, 140, 113,   6, 223, 165,  36, 153, 0, 162, 203, 68, 95, 49, 136, 214, 119, 14, 153, 42, 188, 81, 99, 250, 56, 205, 31, 72, 112, 149, 226, 11, 85, 138, 217, 108, 20, 62, 161, 254]

            "fd_only" : True,
            "can_frame": {
                "id": {"base": 0x280, "extended": None},
                # Combined Vector
                "data" : [26, 195, 79, 130, 157, 94, 11, 119, 52, 145, 250, 98, 24, 231, 92, 160, 43, 109, 142, 19, 71, 251, 144, 82, 62, 140, 113, 6, 223, 165, 36, 153, 0, 162, 203, 68, 95, 49, 136, 214, 119, 14, 153, 42, 188, 81, 99, 250, 56, 205, 31, 72, 112, 149, 226, 11, 85, 138, 217, 108, 20, 62, 161, 254]
            },
            "fi_frames": [
                {
                    "id": "0x281",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0xF", 
                    "err": "none",
                    "data_vec": "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00A2CB445F3188D6770E992ABC5163FA38CD1F487095E20B558AD96C143EA1FE"
                },
            ] 
        },
        {
            "fd_only" : False,
            # DLC 1000
            "can_frame": {
                "id": {"base": 0x0A5, "extended": None},
                "data": [
                    0x5A, 0x6D 
                ]
            },
            "fi_frames": [
                {
                    "id": "0x0A5",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0x2", 
                    "err": "none",
                    "data_vec": "8A0F59FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
                },
            ] 
        },
        {
            "fd_only" : False,
            # DLC 1000
            "can_frame": {
                "id": {"base": 0x280, "extended": None},
                "data": [
                    0x10, 0x22, 0xFF, 0x46, 0x58, 0x6A, 0x7C, 0x8E
                ]
            },
            "fi_frames": [
                {
                    "id": "0x280",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0x8", 
                    "err": "none",
                    # Data Override from the 3rd byte onwards (0xF3 EF A8 12 5A 70)
                    # New CRC from diverged vector (0x 6D 05)
                    "data_vec": "FFFF73EFA8125A706D05FFFF73EFA8125A706D05FFFF73EFA8125A706D05FFFF73EFA8125A706D05FFFF73EFA8125A706D05FFFF73EFA8125A706D05FFFF73EFA8125A706D0"
                },
                {
                    "id": "0x280",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0xC", 
                    "err": "inj_dlc",
                    # Same as abvoe but invalid DLC
                    "data_vec": "FFFF73EFA8125A706D05"
                },
                {
                    "id": "0x280",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0x8", 
                    "err": "none",
                    # Data Override from the 3rd byte onwards (0xF3 EF A8 12 5A 70)
                    # Same as above but invalid CRC. should produce an error frame
                    "data_vec": "FFFF73EFA8125A706D05"
                },
                {
                    "id": "0x280",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0x8", 
                    "err": "inj_dom",
                    # Same as above but ettempting to override a zero
                    "data_vec": "FFFFB3EFA8125A706D05"
                }
            ] 
        },
        {
            "fd_only" : True,
            "can_frame": {
                "id": {"base": 0x280, "extended": None},
                "data": [
                    0x1A, 0xC3, 0x4F, 0x82, 0x9D, 0x5E, 0x0B, 0x77,
                    0x34, 0x91, 0xFA, 0x62, 0x18, 0xE7, 0x5C, 0xA0,
                    0x2B, 0x6D, 0x8E, 0x13, 0x47, 0xFB, 0x90, 0x52,
                    0x3E, 0x8C, 0x71, 0x06, 0xDF, 0xA5, 0x24, 0x99,
                    0x61, 0x4A, 0xBD, 0x73, 0x0C, 0xE5, 0x2F, 0x88,
                    0x1B, 0x94, 0x57, 0xC0, 0x6E, 0x3D, 0x82, 0x0F,
                    0x44, 0x7B, 0x21, 0xD6, 0x89, 0x30, 0xAF, 0x58,
                    0x12, 0x67, 0x9E, 0x3C, 0x85, 0xEA, 0x40, 0xB3
                ]
            },
            "fi_frames": [
                {
                    "id": "0x280",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0xF", 
                    "err": "none",
                    # Same divergence as above at the first 1 0f 0x8 + valid CRC21 0x17A371, 
                    "data_vec": "FFFFFF700B773491FA6218E75CA02B6D8E1347FB90523E8C7106DFA52499614ABD730CE52F881B9457C06E3D820F447B21D68930AF5812679E3C85EA40B317A371"
                },
                {
                    "id": "0x280",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0xF", 
                    "err": "inj_dlc",
                    # Same divergence as above at the first 1 0f 0x8 + valid CRC21 0x17A371, 
                    "data_vec": "FFFFFF700B773491FA6218E75CA02B6D8E1347FB90523E8C7106DFA52499614ABD730CE52F881B9457C06E3D820F447B21D68930AF5812679E3C85EA40B317A371"
                },
                {
                    "id": "0x280",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0xF", 
                    "err": "none",
                    # Same as above but with invalid CRC
                    "data_vec": "FFFFFF700B773491FA6218E75CA02B6D8E1347FB90523E8C7106DFA52499614ABD730CE52F881B9457C06E3D820F447B21D68930AF5812679E3C85EA40B317A372"
                },
                {
                    "id": "0x280",
                    "id_mask": "0x0000000",
                    "type": "data-crc",
                    "field": "",
                    "meta": "0xF", 
                    "err": "inj_dom",
                    # Same as above
                    "data_vec": "F0FFFF700B773491FA6218E75CA02B6D8E1347FB90523E8C7106DFA52499614ABD730CE52F881B9457C06E3D820F447B21D68930AF5812679E3C85EA40B3"
                }
            ] 
        },
    ]
}