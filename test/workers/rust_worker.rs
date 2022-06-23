//
// Port worker example
//

use std::io;
use std::time::SystemTime;
use std::env;


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

    loop {

        let msg = read();

        if msg == "" {
            break
        }

        log(format!("get message: {}", msg));

        // do work

        send(&msg);

        log(format!("message send: {}", msg));
 
    }
}


fn main(){

    let args: Vec<String> = env::args().collect();
    process(args[1..].to_vec());

}
