extern crate mio;
extern crate bytes;

use mio::*;
use mio::net::{TcpListener, TcpStream};

use std::io::{Read, Write};
use std::mem;
use std::collections::{HashMap, VecDeque};

const SERVER: mio::Token = mio::Token(0);

const BUFFER_SIZE: usize = 256;

fn main() {
    let addr = "127.0.0.1:29291".parse().unwrap();
    let server = TcpListener::bind(&addr).unwrap();

    let mut chat = Chat::new(server);
    println!("Listening on {:?}", addr);

    chat.run();
}

struct Chat {
    server: TcpListener,
    connections: HashMap<Token, Connection>,
    poll: Poll,
    next_socket_index: usize,
    must_terminate: bool,
    chat_events: VecDeque<ChatEvent>,
}

enum ChatEvent {
    Join(String),
    Quit(String),
    Message(String, String),
}

impl Chat {
    fn new(server: TcpListener) -> Chat {
        let hashmap = HashMap::new();
        let poll = Poll::new().unwrap();

        Chat {
            server: server,
            connections: hashmap,
            poll: poll,
            next_socket_index: 1,
            must_terminate: false,
            chat_events: VecDeque::new(),
        }
    }

    fn run(&mut self) {
        self.poll.register(&self.server, SERVER, Ready::readable(), PollOpt::edge()).unwrap();

        let mut events = Events::with_capacity(1024);
        while !self.must_terminate {
            self.poll.poll(&mut events, None).unwrap();
            for event in events.iter() {
                self.handle(event);
            }

            let chat_events = std::mem::replace(&mut self.chat_events, VecDeque::new());
            for event in chat_events.iter() {
                self.handle_chat(event);
            }
        }
    }

    fn handle(&mut self, event: Event) {
        match event.token() {
            SERVER => {
                match self.server.accept() {
                    Ok((socket, addr)) => {
                        let token = Token(self.next_socket_index);
                        self.next_socket_index += 1;

                        self.connections.insert(token, Connection::new(socket, token));
                        self.connections.get_mut(&token).unwrap().hello();

                        self.poll.register(
                            &self.connections[&token].socket,
                            token,
                            self.connections[&token].event_set(),
                            PollOpt::edge() | PollOpt::oneshot()).unwrap();
                        println!("new connection {:?} from {:?}", token, addr);
                    }
                    Err(e) => {
                        println!("encountered error while accepting connection; err={:?}", e);
                        self.must_terminate = true;
                    }
                }
            }
            _ => {
                self.connections.get_mut(&event.token()).unwrap().handle(&mut self.poll, event, &mut self.chat_events);

                if self.connections[&event.token()].is_closed() {
                    self.connections.remove(&event.token());
                }
            }
        }
    }

    fn handle_chat(&mut self, event: &ChatEvent) {
        for (_, cli) in self.connections.iter_mut() {
            match *event {
                ChatEvent::Join(ref nick) => {
                    cli.write_line(&format!("* {} joined", nick));
                }
                ChatEvent::Quit(ref nick) => {
                    cli.write_line(&format!("* {} left", nick));
                }
                ChatEvent::Message(ref nick, ref msg) => {
                    cli.write_line(&format!("<{}> {}", nick, msg));
                }
            }
            cli.reregister(&mut self.poll);
        }
    }
}

#[derive(Debug)]
struct Connection {
    socket: TcpStream,
    token: Token,
    read_buf: Vec<u8>,
    write_buf: Vec<u8>,
    nick: Option<String>,
    closed: bool,
}

impl Connection {
    fn new(socket: TcpStream, token: Token) -> Connection {
        Connection {
            socket: socket,
            token: token,
            read_buf: Vec::new(),
            write_buf: Vec::new(),
            nick: None,
            closed: false,
        }
    }

    fn hello(&mut self) {
        self.write_line("Enter your nickname to join the server:");
    }

    fn handle(&mut self, poll: &mut Poll, event: Event, chat_events: &mut VecDeque<ChatEvent>) {
        if self.closed {
            return
        }
        if event.readiness().is_readable() {
            self.read(chat_events);
        }
        if event.readiness().is_writable() {
            self.write();
        }
        if self.closed {
            match self.nick {
                Some(ref nick) => chat_events.push_back(ChatEvent::Quit(nick.clone())),
                _ => {}
            }
        } else {
            self.reregister(poll);
        }
    }

    fn read(&mut self, chat_events: &mut VecDeque<ChatEvent>) {
        let mut buffer: Vec<u8> = vec![0; BUFFER_SIZE];
        match self.socket.read(&mut buffer) {
            Ok(0) => {
                println!("read 0 bytes, considering closed");
                self.closed = true
            }
            Ok(n) => {
                self.read_buf.extend_from_slice(&buffer[..n]);

                while let Some(pos) = self.read_buf.iter().position(|b| *b == b'\n') {
                    let rest = self.read_buf.split_off(pos+1);
                    let line = mem::replace(&mut self.read_buf, rest);
                    let line = std::str::from_utf8(&line).unwrap();
                    let line = line.trim_right();

                    self.process_line(line, chat_events);
                }
            }
            Err(e) => {
                panic!("got an error trying to read; err={:?}", e);
            }
        }
    }

    fn write(&mut self) {
        match self.socket.write(&mut self.write_buf) {
            Ok(0) => {
                println!("wrote 0 bytes, considering closed");
                self.closed = true
            }
            Ok(n) => {
                let rest = self.write_buf.split_off(n);
                self.write_buf = rest;
            }
            Err(e) => {
                panic!("got an error trying to write, err={:?}", e);
            }
        }
    }

    fn process_line(&mut self, line: &str, chat_events: &mut VecDeque<ChatEvent>) {
        match self.nick {
            None => {
                chat_events.push_back(ChatEvent::Join(line.to_string()));
                self.nick = Some(line.to_string())
            }
            Some(ref nick) => {
                println!("<{}> {}", nick, line);
                chat_events.push_back(ChatEvent::Message(nick.clone(), line.to_string()));
            }
        }
    }

    fn write_line(&mut self, what: &str) {
        self.write_buf.extend_from_slice(what.as_bytes());
        self.write_buf.push(b'\n');
    }
    
    fn reregister(&mut self, poll: &mut Poll) {
        poll.reregister(&self.socket, self.token, self.event_set(), PollOpt::oneshot()).unwrap();
    }

    fn event_set(&self) -> Ready {
        if self.write_buf.len() > 0 {
            Ready::readable() | Ready::writable()
        } else {
            Ready::readable()
        }
    }

    fn is_closed(&self) -> bool {
        return self.closed;
    }
}

