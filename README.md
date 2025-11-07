# Chat

## Steps for Execution
1. Run the mix app in the server folderu using a named, distributed and supervised iex shell.
```bash
cd server
iex --name <server-name> -S mix
```
2. There should already be a socket open on `localhost:6666`. To use the client or to create more proxies, go to client and run whichever one you want.
```bash
cd client
iex client.ex <port-number> #default is 6666
```
3. You can also use iex and start a new proxy in a different iex shell inside client. You just have to have the global one from server running
```bash
iex --sname <client-proxy-name> proxy.ex
```
```elixir
c("proxy.ex")
c("server.ex")
Chat.Proxy.start_link( <port-number-string> )
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `chat` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:chat, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/chat>.

