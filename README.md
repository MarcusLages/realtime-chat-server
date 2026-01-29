# Realtime Chat Server
A real-time chat application built with Elixir, supporting one chat room and multiple concurrent users.
## Overview
This is a raw TCP socket-based chat server implementation in Elixir that enables real-time communication between multiple clients across the same chat room.
## Project Structure
```bash
realtime-chat-server-go/
├── client/            # Client-side shell code
├── server/            
│	└── lib
│		└── chat       # Main server implementation
└── assignment1.pdf    # Project documentation from assignment
```
## Running the Project
1. Run the mix app in the `/server` folder using a named, distributed and supervised iex shell.
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
## Available Commands
- All of the commands are case insensitive.
- Users are automatically logged out once their shell/connection is closed.
##### `/NCK <nickname>` 
Login with a username so you can send/receive messages.
##### `/LST` 
Lists logged users.
##### `/MSG <recipients> <message>` 
Sends the same message to all recipients. You can have multiple target recipients by separating them by comma (no spaces, just comma)
- Ex: `/MSG user1,user2 Hello everyone.`
##### `/GRP <groupname> <users>` 
Creates a group with all the users. Whenever a message is sent to a group, the message will be broadcasted to all the users in that group. The group name must start with hash (`#`). To add multiple users, separate them by comma similarly to the `/MSG` command.
## Extra Notes
Access the Go version: [MarcusLages/realtime-chat-server-go](https://github.com/MarcusLages/realtime-chat-server-go)
