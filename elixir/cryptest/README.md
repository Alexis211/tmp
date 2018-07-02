# Cryptest

Tests of peer-to-peer stuff. Right now it's a little chat application with replication of message history over peers. Nothing is secure, contrary to the name of the project.

## Installation

Download and install [Elixir](https://elixir-lang.org/).

```
mix deps.get
mix compile
mix run --no-halt
```

P2P port is 4044 by default, can be changed by setting the `$PORT` environment variable. HTTP interface is on port `$PORT`+1000.

