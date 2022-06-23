//
// Port stream worker example
//

use std::io;
use std::time::SystemTime;
use std::env;
use std::{thread, time};


// API 

fn read() -> String {
    let mut msg = String::new();

    io::stdin().read_line(&mut msg).expect("can't read from stdin");
    msg.pop();

    msg
}

fn send(msg: &String) {
    println!("{}", msg);
}

fn log(msg: String) {

    let sys_time = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap();

    eprintln!("{:?}: {}", sys_time.as_millis(), msg);

}


// Process - actor
//  read - recieve message from world
//  send - send message to world
//  log  -  logging anything



fn process(args: Vec<String>){

    log(format!("start working / args={:?}", args));

    let msg = read();

    log(format!("get start message: {}", msg));

    let secs: u64 = args[0].parse().unwrap();

    let wait_secs = time::Duration::from_millis(secs);


    loop {

        // do work

        send(&msg);
        log(format!("message send: {}", msg));
 
        //wait 
        thread::sleep(wait_secs);

    }
}


fn main(){

    let args: Vec<String> = env::args().collect();
    process(args[1..].to_vec());

}
