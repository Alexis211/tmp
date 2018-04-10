extern crate rand;

use std::io;
use std::cmp::Ordering;
use rand::Rng;

fn main() {
    println!("Guess the number!");

    let secret_number = rand::thread_rng().gen_range(1, 101);
    println!("Let me tell you a secret! The random number is {}", secret_number);

    loop {
        println!("\nPlease input your guess.");

        let mut guess = String::new();
        io::stdin().read_line(&mut guess)
            .expect("stdin read error");

        let guess: u32 = match guess.trim().parse() {
            Ok(v) => v,
            _ => {
                println!("Naughty boy! You were supposed to enter a number!");
                continue
            }
        };

        println!("Your input: {}", guess);

        match guess.cmp(&secret_number) {
            Ordering::Less => println!("Too small..."),
            Ordering::Greater => println!("Too big..."),
            Ordering::Equal => {
                println!("Perfect!");
                break
            }
        }
    }
}
