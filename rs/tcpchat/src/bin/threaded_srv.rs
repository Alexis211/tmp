extern crate bufstream;

use std::str::FromStr;
use std::io::Write;
use std::net::{SocketAddr, TcpListener, TcpStream};
use std::os::unix::io::AsRawFd;
use std::thread::spawn;
use std::io::BufRead;
use std::sync::{Arc, Mutex};
use std::sync::mpsc;
use std::sync::mpsc::{Receiver, Sender};

use bufstream::BufStream;

struct Client {
    id: u32,
    sock: TcpStream,
}

fn handle_connection(id: u32, stream_raw: TcpStream, arc: Arc<Mutex<Vec<Client>>>) {
    let client = Client {
        id: id,
        sock: stream_raw.try_clone().unwrap(),
    };

    let mut stream_buf = BufStream::new(stream_raw);

    let mut name = String::new();
    stream_buf.read_line(&mut name).unwrap();
    let name = name.trim_right();

    println!("New client {}: {}", id, name);

    {
        let mut clients = arc.lock().unwrap();
        clients.push(client);
    }

    loop {
        let mut reads = String::new();
        match stream_buf.read_line(&mut reads) {
            Ok(_) => {
                let reads = reads.trim();
                if reads.len() != 0 {
                    println!("<{}> {}", name, reads);
                    for cli in &mut arc.lock().unwrap().iter_mut() {
                        if cli.id != id {
                            cli.sock
                                .write_fmt(format_args!("<{}> {}\n", name, reads))
                                .unwrap();
                        }
                    }
                }
            }
            _ => break,
        }
    }
    println!("Disconnecting client {}: {}", id, name);
    arc.lock().unwrap().retain(|ref x| x.id != id);
}

fn main() {
    let listener = TcpListener::bind("127.0.0.1:9123").unwrap();

    let arc: Arc<Mutex<Vec<Client>>> = Arc::new(Mutex::new(Vec::new()));

    println!("Listener staring up");
    let mut id: u32 = 0;

    for stream in listener.incoming() {
        match stream {
            Err(_) => println!("listen error"),
            Ok(mut stream) => {
                println!(
                    "Connection from {} to {}",
                    stream.peer_addr().unwrap(),
                    stream.local_addr().unwrap()
                );
                let arc = arc.clone();
                id += 1;
                spawn(move || {
                    handle_connection(id, stream, arc);
                });
            }
        }
    }
}
