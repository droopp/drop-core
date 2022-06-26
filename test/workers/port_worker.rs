//
// Port worker example
//

use std::io;
use std::time::{Duration, SystemTime};
use std::env;
use std::thread;

// API 
//
// Process - actor
//  read - recieve message from world
//  send - send message to world
//  log  -  logging anything


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


fn process(args: Vec<String>){

    log(format!("start working / args={:?}", args));

    let sleep = args[0].parse::<u64>().unwrap();
    let wait_secs = Duration::from_secs(sleep);

    loop {

        let msg = read();

        if msg == "" {
            break
        }

        log(format!("get message: {}", msg));

        // do work
        thread::sleep(wait_secs);

        send(&msg);

        log(format!("message send: {}", msg));
 
    }
}


fn main(){

    let args: Vec<String> = env::args().collect();
    process(args[1..].to_vec());

}
