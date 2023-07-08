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
    let json_str = fs::read_to_string(&args.json_file)?;
    let rm: RegMap = serde_json::from_str(&json_str)?;
    check_regmap(&rm)?;

    if args.vhdl {
        gen_vhdl(&rm);
    }

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
    enums: Option<Vec<EnumDesc>>
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
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ReggieError {
    #[error("invalid character used in identifier")]
    InvalidChar,

    #[error("unknown error")]
    Unknown,
}
*/


/// Convert a hex/dec string into an integer
fn as_int(num: &str) -> i64 {
    todo!();
}

/// convert a hex/dec string into a vhdl slv format
fn as_vhdl_slv(num: &str) -> String {
    todo!();
}

fn check_valid_identifier(identifier: &str) -> Result<(), Box<dyn error::Error>> {

    if identifier.is_empty() {
        return Err("identifier is empty")?;
    }

    let id_lower = identifier.to_ascii_lowercase();

    let first = id_lower.chars().next().unwrap(); 

    if !first.is_ascii_lowercase() {
        let msg = format!("identifier '{}' starts with an invalid character '{}'", identifier, first);
        Err(msg)?
    }

    for id_char in id_lower.chars() {
        if !(id_char.is_ascii_lowercase() || id_char.is_ascii_digit() || id_char == '_') {
            let msg = format!("identifier '{}' contains an invalid character '{}'", identifier, id_char);
            Err(msg)?
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


fn check_valid_numeric(num: &str) -> Result<(), Box<dyn error::Error>> {

    if num.is_empty() {
        return Err("numeric is empty")?;
    }

    let mut num_iter = num.chars();
    let first = num_iter.next().unwrap(); 
    let second = num_iter.next().unwrap(); 

    if first == '0' && second == 'x' {
        for c in num_iter {
            if !(c.is_ascii_hexdigit() || c == '_') {
                let msg = format!("hex numeric '{}' contains an invalid character '{}' ", num, c);
                Err(msg)?;
            }
        }
    } else {
        for c in num.chars() {
            if !(c.is_ascii_digit() || c == '_') {
                let msg = format!("decimal numeric '{}' contains an invalid character '{}' ", num, c);
                Err(msg)?;
            }
        }
    }

    Ok(())
}


// impl RegMap {
//     pub fn new(json_str: &str) -> Self {
//         let rm: RegMap = serde_json::from_str(&contents)?;
//     }
// }



// TODO: remove the first two line of this function
// make it an impl of the RegMap struct
// takes self as input param
// also need to make a "new::" constructor function
// this constructor function will be the first two lines of this current func
// rename it to check_regmap 
// Actually, the constructor could fail since from_str could fail -> we can't do this
//
// I've added checks that validate syntax, next need to add checks that 
// validate logic. for example: reset val can't use more bits than data_width
// addresses can't be repeated - especially need to check this for register arrays
// enum values can't be repeated
// enum values must fit within their bit boundries
// fields can't overlap
// fields can't overflow outside of the register
// no identifiers can be identical at the same level of hiearchy
// 
// TODO: support for "12345", "0x2BCD", "0b1100_00110"
// need to add support for binary data types
fn check_regmap(rm: &RegMap) -> Result<(), Box<dyn error::Error>> {

    if rm.reggie_version != VERSION {
        let msg = format!("input register map file expects version {} of reggie, but this executable is version {}", rm.reggie_version, VERSION);
        Err(msg)?
    }

    if rm.addr_width > 32 {
        let msg = format!("reggie currently only supports a maximum addr_width of 32");
        Err(msg)?
    }

    if rm.data_width != 32 {
        let msg = format!("reggie currently only supports data_width of 32");
        Err(msg)?
    }

    check_valid_identifier(&rm.name)?;

    for reg in rm.regs.iter() {
        check_valid_identifier(&reg.name)?;

        match reg.access.as_str() {
            "RW" | "RO" | "RWV" => (),
            _ => {
                let msg = format!("\"{}\" is an unkown access type. please use \"RW\", \"RO\", or \"RWV\"", &reg.access);
                Err(msg)?
            }
        }

        check_valid_numeric(&reg.addr_offset)?;

        for field in &reg.fields {

            check_valid_identifier(&field.name)?;

            match &field.reset_value {
                Some(r) => check_valid_numeric(r)?,
                None => ()
            }

            match &field.enums {
                Some(e) => {
                    for enu in e {
                        check_valid_numeric(&enu.value)?;
                    } 
                },
                None => (),
            }
        }
    }

    Ok(())
}


fn gen_vhdl(rm: &RegMap) -> String {
    todo!();
}

