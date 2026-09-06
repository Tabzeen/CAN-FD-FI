use clap::{Args, Parser, Subcommand, ValueEnum};
use crate::generated::can_fd_fi::{CanFdFi};

// -----------------------------------------------------------------------------
// CLI ARG PARSE TREE CONFIGURATION
// -----------------------------------------------------------------------------

#[derive(Parser)]
#[command(name = "can-fd-fi-configure", version, about = "CLI Tool to read/write CAN FD FI AXI Registers via UIO")]
pub struct Cli {
    /// Device selector (can1, can2, or uioN)
    pub device: String,

    #[command(subcommand)]
    pub command: Commands,
}


#[derive(Subcommand)]
pub enum Commands {
    Status(StatusTarget),
    ConfCan(ConfCanTarget),
    ConfFi(ConfFiTarget),
    SetFi(SetFiTarget),
    SetVector(SetVectorTarget),
    Enable,
    Disable,
}

// TODO, print the core status as a parsable json structure
#[derive(Args)]
pub struct StatusTarget {
    #[arg(long)]
    pub json: Option<bool>,
}

#[derive(Args)]
pub struct ConfCanTarget {
    #[arg(long)]
    pub brp: Option<u32>,
    #[arg(long)]
    pub dbrp: Option<u32>,
    // Macro required so a value is parsed instead of using the existence of the flag itself as a bool
    #[arg(long, action = clap::ArgAction::Set, value_parser = clap::value_parser!(bool))]
    pub autotdc: Option<bool>,
    #[arg(long)]
    pub ssp: Option<u32>,
    #[arg(long)]
    pub tseg1: Option<u32>,
    #[arg(long)]
    pub dtseg1: Option<u32>,
    #[arg(long)]
    pub tseg2: Option<u32>,
    #[arg(long)]
    pub dtseg2: Option<u32>,
    #[arg(long)]
    pub sjw: Option<u32>,
    #[arg(long)]
    pub dsjw: Option<u32>,
}

#[derive(Args)]
pub struct ConfFiTarget {
    #[arg(long)]
    pub psp: Option<u32>,
    #[arg(long)]
    pub fip: Option<u32>,
    #[arg(long)]
    pub dpsp: Option<u32>,
    #[arg(long)]
    pub dfip: Option<u32>,
}

#[derive(Args)]
pub struct SetFiTarget {
    pub idx: u8,
    #[arg(value_parser = parse_u32_hex)]
    pub id_match: u32,
    #[arg(long, value_parser = parse_u32_hex)]
    pub id_mask: Option<u32>,
    #[command(subcommand)]
    pub fi_type: FiType,
}

#[derive(Subcommand)]
pub enum FiType {
    None,
    Bit {
        #[arg(value_enum)]
        field: TargetField,
        bit: u32,
    },
    FixStuff {
        #[arg(value_enum)]
        field: TargetField,
        idx: u8,
    },
    DynStuff {
        #[arg(value_enum)]
        field: TargetField,
        idx: u8,
    },
    Dlc {
        // DLC
        #[arg(value_parser = parse_u8_hex)]
        dlc_val: u8,
    },
    DataCrc {
        // DLC
        #[arg(value_parser = parse_u8_hex)]
        dlc_val: u8,
    }
}

#[derive(Clone, ValueEnum)]
pub enum TargetField {
    Arbit,
    Ctrl,
    Data,
    CrcStf,
    Crc,
    Eof,
}

#[derive(Args)]
pub struct SetVectorTarget {
    #[arg(value_parser = parse_u8_hex)]
    pub idx: u8,
    // Data
    pub payload: String,
}

// -----------------------------------------------------------------------------
// CLI HANDLER FUNCTIONS
// -----------------------------------------------------------------------------

pub fn dispatch_command(regs: CanFdFi, command: Commands) {
    match command {
        Commands::Status(args) => core_status(regs, args),
        Commands::ConfCan(args) => conf_can(regs, args),
        Commands::ConfFi(args) => conf_fi(regs, args),
        Commands::SetFi(args) => set_fi(regs, args),
        Commands::SetVector(args) => set_vec(regs, args),
        Commands::Enable => regs.set_global_config_cfg_en(false),
        Commands::Disable => regs.set_global_config_cfg_en(true),
    }
}


fn core_status(regs: CanFdFi, _args: StatusTarget) {
    let info = regs.get_core_info();
    let ver = regs.get_core_version();

    println!("CORE_INFO.info_t   = {:#010X}", info.info_t);
    println!("CORE_VERSION       = {}.{}.{} (magic {:#04X})", ver.major, ver.minor, ver.patch, ver.magic_valid);
    println!("STATUS_FLAGS       = {:?}", regs.get_status_flags());
    println!("GLOBAL_CONFIG      = {:?}", regs.get_global_config());
    println!("NOMINAL_CONFIG     = {:?}", regs.get_nominal_config());
    println!("DATA_CONFIG        = {:?}", regs.get_data_config());
    println!("FI_CONFIG          = {:?}", regs.get_fi_config());

    println!("--------------------------------------------------");
    for i in 0..=7 {
        let (match_val, mask_val, fif_val) = match i {
            0 => (
                regs.get_id_mem0_match_idm0_match(),
                regs.get_id_mem0_mask_idm0_mask(),
                regs.get_id_mem0_fif_idm0_fif(),
            ),
            1 => (
                regs.get_id_mem1_match_idm1_match(),
                regs.get_id_mem1_mask_idm1_mask(),
                regs.get_id_mem1_fif_idm1_fif(),
            ),
            2 => (
                regs.get_id_mem2_match_idm2_match(),
                regs.get_id_mem2_mask_idm2_mask(),
                regs.get_id_mem2_fif_idm2_fif(),
            ),
            3 => (
                regs.get_id_mem3_match_idm3_match(),
                regs.get_id_mem3_mask_idm3_mask(),
                regs.get_id_mem3_fif_idm3_fif(),
            ),
            4 => (
                regs.get_id_mem4_match_idm4_match(),
                regs.get_id_mem4_mask_idm4_mask(),
                regs.get_id_mem4_fif_idm4_fif(),
            ),
            5 => (
                regs.get_id_mem5_match_idm5_match(),
                regs.get_id_mem5_mask_idm5_mask(),
                regs.get_id_mem5_fif_idm5_fif(),
            ),
            6 => (
                regs.get_id_mem6_match_idm6_match(),
                regs.get_id_mem6_mask_idm6_mask(),
                regs.get_id_mem6_fif_idm6_fif(),
            ),
            7 => (
                regs.get_id_mem7_match_idm7_match(),
                regs.get_id_mem7_mask_idm7_mask(),
                regs.get_id_mem7_fif_idm7_fif(),
            ),
            _ => unreachable!(),
        };
        
        println!(
            "ID_MEM[{}]          = Match: {:#010X} | Mask: {:#010X} | FIF: {:#010X}",
            i, match_val, mask_val, fif_val
        );
    }
}

fn conf_can(regs: CanFdFi, args: ConfCanTarget) {
    if let Some(brp) = args.brp { regs.set_global_config_cfg_brp_nomi(brp); }
    if let Some(dbrp) = args.dbrp { regs.set_global_config_cfg_brp_data(dbrp); }
    if let Some(autotdc) = args.autotdc { regs.set_global_config_cfg_td_en(autotdc); }
    if let Some(ssp) = args.ssp { regs.set_global_config_cfg_ssp(ssp); }
    if let Some(tseg1) = args.tseg1 { regs.set_nominal_config_cfg_ph1_len_nomi(tseg1); }
    if let Some(dtseg1) = args.dtseg1 { regs.set_data_config_cfg_ph1_len_data(dtseg1); }
    if let Some(tseg2) = args.tseg2 { regs.set_nominal_config_cfg_ph2_len_nomi(tseg2); }
    if let Some(dtseg2) = args.dtseg2 { regs.set_data_config_cfg_ph2_len_data(dtseg2); }
    if let Some(sjw) = args.sjw { regs.set_nominal_config_cfg_sjw_nomi(sjw); }
    if let Some(dsjw) = args.dsjw { regs.set_data_config_cfg_sjw_data(dsjw); }
}

fn conf_fi(regs: CanFdFi, args: ConfFiTarget) {
    if let Some(psp) = args.psp { regs.set_fi_config_cfg_psp_nomi(psp); }
    if let Some(dpsp) = args.dpsp { regs.set_fi_config_cfg_psp_data(dpsp); }
    if let Some(fip) = args.fip { regs.set_fi_config_cfg_fip_nomi(fip); }
    if let Some(dfip) = args.dfip { regs.set_fi_config_cfg_fip_data(dfip); }
}

fn set_fi(regs: CanFdFi, args: SetFiTarget) {

    // If no mask is provided, just use all bits 
    let mask = args.id_mask.unwrap_or(0x1FFF_FFFF);

    match args.idx {
        0 => {
            regs.set_id_mem0_match_idm0_match(args.id_match);
            regs.set_id_mem0_mask_idm0_mask(mask);
        }
        1 => {
            regs.set_id_mem1_match_idm1_match(args.id_match);
            regs.set_id_mem1_mask_idm1_mask(mask);
        }
        2 => {
            regs.set_id_mem2_match_idm2_match(args.id_match);
            regs.set_id_mem2_mask_idm2_mask(mask);
        }
        3 => {
            regs.set_id_mem3_match_idm3_match(args.id_match);
            regs.set_id_mem3_mask_idm3_mask(mask);
        }
        4 => {
            regs.set_id_mem4_match_idm4_match(args.id_match);
            regs.set_id_mem4_mask_idm4_mask(mask);
        }
        5 => {
            regs.set_id_mem5_match_idm5_match(args.id_match);
            regs.set_id_mem5_mask_idm5_mask(mask);
        }
        6 => {
            regs.set_id_mem6_match_idm6_match(args.id_match);
            regs.set_id_mem6_mask_idm6_mask(mask);
        }
        7 => {
            regs.set_id_mem7_match_idm7_match(args.id_match);
            regs.set_id_mem7_mask_idm7_mask(mask);
        }
        _ => panic!("Slot index {} out of bounds (0..=7 expected)", args.idx),
    }

    let field_to_code = |field: TargetField| -> u32 {
        match field {
            TargetField::Arbit  => 0b000,
            TargetField::Ctrl   => 0b001,
            TargetField::Data   => 0b011,
            TargetField::CrcStf => 0b100,
            TargetField::Crc    => 0b101,
            TargetField::Eof    => 0b110,
        }
    };

    let (one_hot_type, field_code, meta) = match args.fi_type {
        FiType::None => (0b000001, 0b000, 0),
        FiType::Bit { field, bit } => (0b000010, field_to_code(field), bit & 0x1FF),
        FiType::FixStuff { field, idx } => (0b010000, field_to_code(field), (idx as u32) & 0x1FF),
        FiType::DynStuff { field, idx } => (0b001000, field_to_code(field), (idx as u32) & 0x1FF),
        FiType::Dlc { dlc_val } => (0b000100, 0b000, (dlc_val as u32) & 0x1FF),
        FiType::DataCrc { dlc_val } => (0b100000, 0b000, (dlc_val as u32) & 0x1FF),
    };

    let fif_val: u32 = ((one_hot_type & 0x3F) << 12) 
                     | ((field_code & 0x7) << 9) 
                     | (meta & 0x1FF);

    match args.idx {
        0 => regs.set_id_mem0_fif_idm0_fif(fif_val),
        1 => regs.set_id_mem1_fif_idm1_fif(fif_val),
        2 => regs.set_id_mem2_fif_idm2_fif(fif_val),
        3 => regs.set_id_mem3_fif_idm3_fif(fif_val),
        4 => regs.set_id_mem4_fif_idm4_fif(fif_val),
        5 => regs.set_id_mem5_fif_idm5_fif(fif_val),
        6 => regs.set_id_mem6_fif_idm6_fif(fif_val),
        7 => regs.set_id_mem7_fif_idm7_fif(fif_val),
        _ => unreachable!(),
    }
}

// TODO: Untested requires ILA
fn set_vec(regs: CanFdFi, args: SetVectorTarget) {
    const PLD_SEG_STRIDE: u32 = 32;
    let mut words = [0u32; 18];

    let hex_str = args.payload.strip_prefix("0x")
        .or_else(|| args.payload.strip_prefix("0X"))
        .unwrap_or(&args.payload);

    for i in 0..18 {
        let start = i * 8;
        
        if start >= hex_str.len() {
            break;
        }
        
        let end = std::cmp::min(start + 8, hex_str.len());
        let mut slice = hex_str[start..end].to_string();
        
        if slice.len() < 8 {
            slice.push_str(&"0".repeat(8 - slice.len()));
        }
        
        words[i] = u32::from_str_radix(&slice, 16)
            .expect("Invalid hex character provided in payload");
    }
    for (seg_idx, &word) in words.iter().enumerate() {
        let target_seg = 17 - (seg_idx as u32);
        let ram_addr = (args.idx as u32) * PLD_SEG_STRIDE + target_seg;
        
        regs.set_mu_ram_data_ram_data_payload(word);
        regs.set_mu_cfg_addr_ram_data_address(ram_addr);
        regs.set_mu_cfg_base_ram_data_valid(true);
        regs.set_mu_cfg_base_ram_data_valid(false);
    }
}

// Parser Functions
fn parse_u32_hex(s: &str) -> Result<u32, std::num::ParseIntError> {
    if let Some(stripped) = s.strip_prefix("0x").or_else(|| s.strip_prefix("0X")) {
        u32::from_str_radix(stripped, 16)
    } else {
        s.parse::<u32>()
    }
}

fn parse_u8_hex(s: &str) -> Result<u8, std::num::ParseIntError> {
    if let Some(stripped) = s.strip_prefix("0x").or_else(|| s.strip_prefix("0X")) {
        u8::from_str_radix(stripped, 16)
    } else {
        s.parse::<u8>()
    }
}