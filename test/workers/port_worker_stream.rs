//
// Port stream worker example
//

use std::time::SystemTime;
use std::env;
use std::{thread, time};


// API 
//
// Process - actor
//  send - send message to world
//  log  -  logging anything


fn send(msg: &String) {
    println!("{}", msg);
}

fn log(msg: String) {

    let sys_time = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap();
    eprintln!("{:?}: {}", sys_time.as_millis(), msg);

}



fn process(args: Vec<String>){

    log(format!("start working / args={:?}", args));

    let secs = match args.len() {
        0 => 3000,
        _ => args[0].parse().unwrap()
    };
    
    let wait_secs = time::Duration::from_millis(secs);


    loop {

        // do work
        //
        let response: String = "ok".to_string();

        send(&response);
        log(format!("message send: {}", response));
 
        //wait 
        thread::sleep(wait_secs);

    }
}


fn main(){

    let args: Vec<String> = env::args().collect();
    process(args[1..].to_vec());

}
