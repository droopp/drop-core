//
// Port worker example
//

use std::io;
use std::time::SystemTime;
use std::env;
use std::sync::mpsc::{Receiver, Sender, channel};
use std::thread;
use std::time;


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

//
// pub-sub spmc implemantation
//

struct PoolWorker {

    //
    //   pub  ->   txw1 ->  rxw1 ->   worker1
    //    |       rx   <-  tx1 <-     |
    //    |                           |
    //  status  <--------------------- 
    //    .                           |
    //    ....  -> txw2 ->  rxw2 ->   worker2
    //             rx   <-  tx2  <-   
    //

    num: u32
}


impl PoolWorker {

    fn get_router(&self) -> (Sender<u32>, Receiver<u32>, Sender<u32>, Receiver<u32>){

        //main pub channel
        let (tx_p, rx_p) = channel();

        //status channel
        let (tx_s, rx_s) = channel();

        (tx_p, rx_p, tx_s, rx_s)

    }

    fn get_bus(&self, tx: Sender<u32>) -> (Vec<Sender<String>>, Vec<(u32, Sender<u32>, Receiver<String>)>) {

        let mut queue: Vec<Sender<String>> = vec![];
        let mut workers: Vec<(u32, Sender<u32>, Receiver<String>)> = vec![];

        for i in 0..self.num {

            let tx1 = tx.clone();
            let (txw1, rxw1) = channel();

            queue.push(txw1);
            workers.push( (i, tx1, rxw1) );
        };

        (queue, workers)

    }

    fn new(num: u32) -> Self {
    
        PoolWorker{num: num}

    }

}


//PUB 
fn run_reader(txs: Vec<Sender<String>>, rx: Receiver<u32>){

    loop{

        let msg = read();

        // workers queue
        // get free and pass msg
        let idx = rx.recv().unwrap();
        txs[idx as usize].send(msg).unwrap();
    }

}


//Status worker
fn run_status(rx: Receiver<u32>, tx: Sender<u32>){

    loop{
        let msg = rx.recv().unwrap();
        tx.send(msg).unwrap();
    }
}


//SUB
fn run_worker(w: (u32, Sender<u32>, Receiver<String>), sleep: u64){

    let (id, tx, rx) = w;
    //init / register status
    tx.send(id).unwrap();
 
    let wait_secs = time::Duration::from_secs(sleep);

    loop {

        //read message
        let msg = rx.recv().unwrap();

        log(format!("worker {} get message: {}",id, msg));

        // do work
        thread::sleep(wait_secs);

        // send message
        send(&msg);

        log(format!("message send: {}", msg));

        // send done message to status
        tx.send(id).unwrap();
 
    }

}

fn process(args: Vec<String>){

    log(format!("process: {:?}", args));

    let pool = PoolWorker::new(args[0].parse::<u32>().unwrap());

    let (tx, rx, tx_status, rx_status) = pool.get_router();
    let(queue, workers) = pool.get_bus(tx);

    //PUB
    let input = thread::spawn(move|| {
        run_reader(queue, rx_status);
    });
 
    //status
    let status = thread::spawn(move|| {
        run_status(rx, tx_status);
    });
 

    //SUBs
    let mut workerh = vec![];

    for w in workers {

        let sleep = args[1].parse::<u64>().unwrap();

        let handler = thread::spawn(move|| {
            run_worker(w, sleep);
        });

        workerh.push(handler);

   }

   // join to main
   input.join().unwrap();
   status.join().unwrap();

   for w in workerh {
       w.join().unwrap();
   }

}


fn main(){

    let args: Vec<String> = env::args().collect();
    process(args[1..].to_vec());

}

