SQL-Email
=========

Makes e-mail accessible via SQL from client-side

Obsolete IMAP convoluted data structure, more flexible than JMAP.

Build
-----

Server part:

    nimble c src/sqlemail

Client part:

    npm install
    npm run build

Run
---

Server part:

    src/sqlemail

Client part:

    npm run dev

Use
---

Send e-mails via LMTP to localhost:2525

Depending on what you are working on:

  - Connect to http://localhost:5273/app/ to get to the front-end app auth
    automatic reload and proxying the backend server on port 8080

  - Connect to http://localhost:8080/ to connect to the backend server that can
    also serve the frontend app if it was build previously.

Roadmap
-------

- [x] Implement LMTP server
- [x] LMTP should insert into SQL ~~raw email~~ after emailparser parsing
- [x] ~~insert job should run after the insert a parsing task that uses
  emailparser to split the different message parts~~
- [x] HTTP API to access the SQL database
- [x] Basic javascript client to access the database
- [x] Add account management and multiple sqlite databases
- [x] OAuth for the API
- [ ] Handle sending e-mails (for OAuth TOTP) from Exim within Docker
- [ ] Configure Exim volume within Docker (persist email spool)
- [ ] Add full text search to SQLite
- [ ] Add function in SQLite to decode:
    - [ ] message parts (transfer encoding and charset to UTF-8)
    - [ ] header values
- [x] handle master / replica model
    - [x] HTTP (Login, user creation)
    - [x] SMTP, forward to master
    - [x] Test SMTP
    - [ ] Test HTTP
- [ ] Handle e-mail threading
    - many to many relation between a mail and a thread
    - thread is computed at insertion time and can be later modified by the user
      agent
    - based on subject and message-id
