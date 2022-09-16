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

    let sleep = match args.len() == 1 {
        false => 0,
        true => args[0].parse().unwrap()
    };
 

    let wait_secs = Duration::from_millis(sleep);

    loop {

        let msg = read();

        if msg == "" {
            break
        }

        if msg == "error" {

            panic!("error occured");

        }

        log(format!("get message: {}", msg));

        // do work
        thread::sleep(wait_secs);

        let response: String = "ok".to_string();

        send(&response);

        log(format!("message send: {}", response));
 
    }
}


fn main(){

    let args: Vec<String> = env::args().collect();
    process(args[1..].to_vec());

}
