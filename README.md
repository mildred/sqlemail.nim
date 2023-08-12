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

- [ ] Implement LMTP server
- [ ] LMTP should insert into SQL raw email
- [ ] insert job should run after the insert a parsing task that uses
  emailparser to split the different message parts
- [ ] HTTP API to access the SQL database
- [ ] Basic javascript client to access the database
- [ ] Add account management and multiple sqlite databases
- [ ] OAuth for the API
