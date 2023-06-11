use std::fs;
use serde::{Serialize, Deserialize};
use serde_json::{Result};



fn main() {
    let file_path = "/home/david/SynologyDrive/cloud_drive/prj/dev/vhdl_lib/reggie/scripts/reggie/src/examp.json"; 
    let contents = fs::read_to_string(file_path)
        .expect("Error reading file");

    let reg_map = parse_json(&contents);
    println!("{:#?}", reg_map);

}

/* 
struct ToolOutputs {
    vhdl_axil: bool,
    vhdl_bus: bool,
    sv_axi: bool,
    sv_bus: bool,
    c_driver: bool,
    markdown_doc: bool,
}
*/

#[derive(Serialize, Deserialize, Debug)]
struct RegMap {
    name: String,
    desc: Option<String>,
    addr_width: u32,
    data_width: u32,
    version: String,
    regs: Vec<Reg>
}

#[derive(Serialize, Deserialize, Debug)]
struct Reg {
    array: Option<bool>, // optional (default to false if not present)
    array_length: Option<u32>, // optional, but required if array is present
    name: String, // must only have valid VHDL characters. need to check for keywords in c, rust, and vhdl. must ber less than a certian number of characters too.
    desc: Option<String>,
    access: String, // "CTL", "STS", "IRQ"
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


fn parse_json(json_str: &str) -> Result<RegMap> {
    let reg_map: RegMap = serde_json::from_str(json_str)?;
    Ok(reg_map)
}



// fn parse_command() {

// }
