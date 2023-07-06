use std::fs;
use std::error; 
use serde::{Serialize, Deserialize};
use serde_json;
use clap::Parser;
use std::path;

//let file_path = "/home/david/SynologyDrive/cloud_drive/prj/dev/vhdl_lib/reggie/scripts/reggie/src/examp.json"; 

const VERSION: &'static str = env!("CARGO_PKG_VERSION");

fn main() -> Result<(), Box<dyn error::Error>> {
    let args = Args::parse();
    let rm: RegMap = parse_json(&args.json_file)?;

    println!("{:#?}", rm);

    println!("json: {:?}", args.json_file);
    println!("vhdl: {:?}", args.vhdl);


    Ok(())
}

/// Reggie CLI arguments
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// JSON register description file
    #[arg(short, long)]
    json_file: path::PathBuf,

    /// Generate VHDL registers
    #[arg(short, long)]
    vhdl: bool,

    /// Generate a VHDL VUnit testbench
    #[arg(short, long)]
    testbench: bool,

    /// Generate C drivers
    #[arg(short, long)]
    c_drivers: bool,

    /// Generate bitfield documentation
    #[arg(short, long)]
    bitfield: bool,
}


#[derive(Serialize, Deserialize, Debug)]
struct RegMap {
    name: String,
    desc: Option<String>,
    addr_width: u32,
    data_width: u32,
    reggie_version: String,
    regs: Vec<Reg>
}

#[derive(Serialize, Deserialize, Debug)]
struct Reg {
    array: Option<bool>, // optional (default to false if not present)
    array_length: Option<u32>, // optional, but required if array is present
    name: String, // must only have valid VHDL characters. need to check for keywords in c, rust, and vhdl. must ber less than a certian number of characters too.
    desc: Option<String>,
    access: String, // "RW", "RO", "RWV"
    addr_offset: String, // hex - well... first support hex only, then move to supporting binary/decimal
    fields: Vec<Field>
}

#[derive(Serialize, Deserialize, Debug)]
struct Field {
    name: String,
    desc: Option<String>,
    bit_width: u32,
    bit_offset: u32,
    reset_value: Option<String>, // hex - optional (default to 0 if not present)
    enum_desc: Option<Vec<EnumDesc>>
}

#[derive(Serialize, Deserialize, Debug)]
struct EnumDesc {
    name: String,
    value: String, // hex
}


const VHDL_KEYWORDS: &'static [&'static str] = &[
    "abs", 
    "access", 
    "after",
    "alias",
    "all",
    "and",
    "architecture",
    "array",
    "assert",
    "attribute",
    "begin",
    "block",
    "body",
    "buffer",
    "bus",
    "case",
    "component",
    "configuration",
    "constant",
    "disconnect",
    "downto",
    "else",
    "elsif",
    "end",
    "entity",
    "exit",
    "file",
    "for",
    "function",
    "generate",
    "generic",
    "group",
    "guarded",
    "if",
    "impure",
    "in",
    "inertial",
    "inout",
    "is",
    "label",
    "library",
    "linkage",
    "literal",
    "loop",
    "map",
    "mod",
    "nand",
    "new",
    "next",
    "nor",
    "not",
    "null",
    "of",
    "on",
    "open",
    "or",
    "others",
    "out",
    "package",
    "port",
    "postponed",
    "procedure",
    "process",
    "pure",
    "range",
    "record",
    "register",
    "reject",
    "rem",
    "report",
    "return",
    "rol",
    "ror",
    "select",
    "severity",
    "signal",
    "shared",
    "sla",
    "sll",
    "sra",
    "srl",
    "subtype",
    "then",
    "to",
    "transport",
    "type",
    "unaffected",
    "units",
    "until",
    "use",
    "variable",
    "wait",
    "when",
    "while",
    "with",
    "xnor",
    "xor",
];

const C_KEYWORDS: &'static [&'static str] = &[
    "auto", 
    "break", 
    "case", 
    "char", 
    "continue", 
    "do", 
    "default", 
    "const", 
    "double", 
    "else", 
    "enum", 
    "extern", 
    "for", 
    "if", 
    "goto", 
    "float", 
    "int", 
    "long", 
    "register", 
    "return", 
    "signed", 
    "static", 
    "sizeof", 
    "short", 
    "struct", 
    "switch", 
    "typedef", 
    "union", 
    "void", 
    "while", 
    "volatile", 
    "unsigned", 
];

/* 
const VALID_START_CHARS: &'static [char] = &[
    'a', 
    'b', 
    'c', 
    'd', 
    'e', 
    'f', 
    'g', 
    'h', 
    'i', 
    'j', 
    'k', 
    'l', 
    'm', 
    'n', 
    'o', 
    'p', 
    'q', 
    'r', 
    's', 
    't', 
    'u', 
    'v', 
    'w', 
    'x', 
    'y', 
    'z', 
];

const VALID_CHARS: &'static [char] = &[
    'a', 
    'b', 
    'c', 
    'd', 
    'e', 
    'f', 
    'g', 
    'h', 
    'i', 
    'j', 
    'k', 
    'l', 
    'm', 
    'n', 
    'o', 
    'p', 
    'q', 
    'r', 
    's', 
    't', 
    'u', 
    'v', 
    'w', 
    'x', 
    'y', 
    'z', 
    '0', 
    '1', 
    '2', 
    '3', 
    '4', 
    '5', 
    '6', 
    '7', 
    '8', 
    '9', 
    '_', 
];
*/


/*
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ReggieError {
    #[error("invalid character used in identifier")]
    InvalidChar,

    #[error("unknown error")]
    Unknown,
}
*/

fn check_valid_identifier(identifier: &str) -> Result<(), Box<dyn error::Error>> {

    if identifier.is_empty() {
        return Err("identifier is empty")?;
    }

    let id_lower = identifier.to_ascii_lowercase();

    let first = id_lower.chars().next().unwrap(); 
    match first {
        'a' | 
        'b' | 
        'c' | 
        'd' | 
        'e' | 
        'f' | 
        'g' | 
        'h' | 
        'i' | 
        'j' | 
        'k' | 
        'l' | 
        'm' | 
        'n' | 
        'o' | 
        'p' | 
        'q' | 
        'r' | 
        's' | 
        't' | 
        'u' | 
        'v' | 
        'w' | 
        'x' | 
        'y' | 
        'z' => (),
        _ => {
            let msg = format!("identifier '{}' starts with an invalid character '{}'", identifier, first);
            Err(msg)?
        },
    }

    for id_char in id_lower.chars() {
        match id_char {
            'a' |
            'b' |
            'c' |
            'd' |
            'e' |
            'f' |
            'g' |
            'h' |
            'i' |
            'j' |
            'k' |
            'l' |
            'm' |
            'n' |
            'o' |
            'p' |
            'q' |
            'r' |
            's' |
            't' |
            'u' |
            'v' |
            'w' |
            'x' |
            'y' |
            'z' |
            '0' |
            '1' |
            '2' |
            '3' |
            '4' |
            '5' |
            '6' |
            '7' |
            '8' |
            '9' |
            '_' => (),
            _ => {
                let msg = format!("identifier '{}' contains an invalid character '{}'", identifier, id_char);
                Err(msg)?
            },
        }
    }

    for kw in VHDL_KEYWORDS {
        if id_lower == *kw {
            let msg = format!("identifier '{}' is a VHDL keyword", identifier);
            Err(msg)?;
        }
    }

    for kw in C_KEYWORDS {
        if id_lower == *kw {
            let msg = format!("identifier '{}' is a C keyword", identifier);
            Err(msg)?;
        }
    }

    Ok(())
}

fn parse_json(json_file: &path::PathBuf) -> Result<RegMap, Box<dyn error::Error>> {
    let contents = fs::read_to_string(&json_file)?;
    let rm: RegMap = serde_json::from_str(&contents)?;

    if rm.reggie_version != VERSION {
        let msg = format!("input register map file expects version {} of reggie, but this executable is version {}", rm.reggie_version, VERSION);
        Err(msg)?
    }

    check_valid_identifier(&rm.name)?;
    

    Ok(rm)
}



fn gen_vhdl(rm: RegMap) {

}

