use std::fs;
use std::error; 
use serde::{Serialize, Deserialize};
use serde_json;
use clap::Parser;
use std::path;

//let file_path = "/home/david/SynologyDrive/cloud_drive/prj/dev/vhdl_lib/reggie/scripts/reggie/data/examp.json"; 

const VERSION: &'static str = env!("CARGO_PKG_VERSION");

fn main() -> Result<(), Box<dyn error::Error>> {
    let args = Args::parse();
    let json_str = fs::read_to_string(&args.json_file)?;
    let rm: RegMap = serde_json::from_str(&json_str)?;
    check_regmap(&rm)?;

    if args.vhdl {
        gen_vhdl(&rm);
    }
    if args.markdown {
        let markdown = gen_markdown(&rm);
        fs::write("examp_output.md", markdown)?;
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

    /// Generate markdown documentation
    #[arg(short, long)]
    markdown: bool,
}

// JSON versions of the register map structs for serde_json
#[derive(Serialize, Deserialize, Debug)]
struct RegMap {
    name: String,
    desc: Option<String>,
    long_desc: Option<String>,
    addr_width: u32,
    data_width: u32,
    reggie_version: String,
    regs: Vec<Reg>
}

#[derive(Serialize, Deserialize, Debug)]
struct Reg {
    array_length: Option<u32>, // optional, defaults to 1
    name: String, // must only have valid VHDL characters. need to check for keywords in c, rust, and vhdl. must ber less than a certian number of characters too.
    desc: Option<String>,
    long_desc: Option<String>,
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


/// Convert a hex/dec string into a Rust integer
fn as_int(num: &str) -> i64 {
    todo!();
}

/// convert a hex/dec string into a vhdl slv
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
        let msg = format!("numeric '{}' is empty ", num);
        return Err(msg)?;
    }

    let mut num_iter = num.chars();
    let first; 
    match num_iter.next() {
        Some(n) => first = n,
        None => first = ' ',
    }
    let second; 
    match num_iter.next() {
        Some(n) => second = n,
        None => second = ' ',
    }

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
// Address boundries must be aligned
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


fn gen_markdown(rm: &RegMap) -> String {
    let mut s = String::new();

    s.push_str(&format!("# {} Register Map\n\n", &rm.name)); 

    match &rm.desc {
        Some(d) => s.push_str(&format!("#### {}\n\n", d)),
        None => (),
    }

    match &rm.long_desc {
        Some(ld) => s.push_str(&format!("{}\n\n", ld)),
        None => (),
    }

    s.push_str(&format!("### {} Attributes\n\n", &rm.name)); 
    s.push_str("| | |\n");
    s.push_str("| --- | --- |\n"); 
    s.push_str(&format!("| Data Width | {} |\n", &rm.data_width)); 
    s.push_str(&format!("| Address Width | {} |\n", &rm.addr_width)); 
    s.push_str(&format!("| Reggie Version | {} |\n\n", &rm.reggie_version));

    s.push_str(&format!("### {} Summary\n\n", &rm.name)); 

    s.push_str("| Register Name | Array | Address Offset | Access | Description |\n");
    s.push_str("| --- | --- | --- | --- | --- |\n");

    for r in rm.regs.iter() {
        let array_length; 
        match &r.array_length {
            Some(len) => array_length = *len,
            None => array_length = 1,
        }

        let desc; 
        match &r.desc {
            Some(d) => desc = d.as_str(),
            None => desc = " ",
        }

        let addr_offset; 
        if array_length > 1 {
            let step = rm.data_width / 8; 
            addr_offset = format!("{} to {}+{}*{}", r.addr_offset, r.addr_offset, step, array_length-1); 
        } else {
            addr_offset = format!("{}", r.addr_offset); 
        }

        s.push_str(&format!("| {} | {} | {} | {} | {} |\n", &r.name, array_length, addr_offset, r.access, desc));
    }
    s.push_str("\n");


    for r in rm.regs.iter() {
        s.push_str(&format!("## {}\n\n", &r.name));

        match &r.desc {
            Some(d) => s.push_str(&format!("#### {}\n\n", d)),
            None => (),
        }
    
        match &r.long_desc {
            Some(ld) => s.push_str(&format!("{}\n\n", ld)),
            None => (),
        }

        s.push_str(&format!("### {} Attributes\n\n", &r.name));

        let array_length; 
        match &r.array_length {
            Some(len) => array_length = *len,
            None => array_length = 1,
        }

        let addr_offset; 
        if array_length > 1 {
            let step = rm.data_width / 8; 
            addr_offset = format!("{} to {}+{}*{}", r.addr_offset, r.addr_offset, step, array_length-1); 
        } else {
            addr_offset = format!("{}", r.addr_offset); 
        }

        s.push_str("| | |\n");
        s.push_str("| --- | --- |\n"); 
        s.push_str(&format!("| Array | {} |\n", array_length)); 
        s.push_str(&format!("| Address Offset | {} |\n", addr_offset)); 
        s.push_str(&format!("| Access | {} |\n\n", r.access)); 


        s.push_str(&format!("### {} Bitfield\n\n", &r.name));

        // Create a vector of the fields including the derived start and stop bits
        // for each field
        let mut fields_start_stop = Vec::<FieldStartStop>::new(); 
        for f in r.fields.iter() {
            let start = f.bit_offset + f.bit_width - 1;
            let stop = f.bit_offset;
            let field = f;
            fields_start_stop.push(FieldStartStop {start: start.into(), stop: stop.into(), field: Some(field)});
        }
        // Sort the fields vector by its start bits (largest to smallest)
        fields_start_stop.sort_by(|a, b| b.start.cmp(&a.start));

        // Add in blank fields to fill in the unused sections of the bitfield
        let mut sorted_fields_blanks = Vec::<FieldStartStop>::new();
        let mut top: u32 = rm.data_width; // 32 in most cases
        for f in fields_start_stop.iter() {
            if f.start < top-1 {
                let blank = FieldStartStop {
                    start: top - 1, 
                    stop: f.start + 1, 
                    field: None 
                };
                top = f.stop;
                sorted_fields_blanks.push(blank);
                sorted_fields_blanks.push(*f); 

            } else if f.start == top-1 {
                top = f.stop;
                sorted_fields_blanks.push(*f); 
            } else {
                // Should never ever reach this point
                panic!("Error: start should never be greater than top"); 
            }
        }
        // This coverts the case when a register definition does not have a field
        // at the zero-bit position
        if top > 0 {
            let blank = FieldStartStop {
                start: top - 1, 
                stop: 0, 
                field: None 
            };
            sorted_fields_blanks.push(blank);
        }

        // Now that we're sorted and blanked, we can create the bitfield
        for f in sorted_fields_blanks.iter() {
            let string; 
            if f.start == f.stop {
                string = format!("| {} ", f.start);
            } else {
                string = format!("| {}:{} ", f.start, f.stop);
            }
            s.push_str(&string);
        }
        s.push_str("|\n");

        for _ in sorted_fields_blanks.iter() {
            s.push_str("| --- ");
        }
        s.push_str("|\n");

        for f in sorted_fields_blanks.iter() {
            match f.field {
                Some(n) => s.push_str(&format!("| {} ", &n.name)),
                None => s.push_str("| - "),
            }
        }
        s.push_str("|\n\n");

        // Fields
        s.push_str("| Bits | Field Name | Reset Value | Description |\n");
        s.push_str("| --- | --- | --- | --- |\n");
        for f in sorted_fields_blanks.iter() {
            let bits; 
            if f.start == f.stop {
                bits = format!("{}", f.start);  
            } else {
                bits = format!("{}:{}", f.start, f.stop);
            }
            
            let name;
            let reset_value;
            let desc;
            let mut enums = String::from(""); 
            match f.field {
                Some(fld) => {
                    name = fld.name.as_str();
                    reset_value = match &fld.reset_value {
                        Some(rv) => rv,
                        None => "0",
                    };
                    desc = match &fld.desc { 
                        Some(de) => de,
                        None => " ",
                    };
                    match &fld.enums { 
                        Some(ens) => {
                            for en in ens {
                                enums.push_str(&format!("<br>{}: {}", en.name, en.value));
                            }
                        },
                        None => {
                           ();
                        },
                    };
                },
                None => {
                    name = "-";
                    reset_value = "-"; 
                    desc = "-"; 
                }
            }
            s.push_str(&format!("| {} | {} | {} | {}{} |\n", &bits, name, reset_value, desc, enums));

        }
        s.push_str("\n\n");
    }

    s
}

#[derive(Debug, Clone, Copy)]
struct FieldStartStop<'a> {
    start: u32,
    stop: u32,
    field: Option<&'a Field>,
}
