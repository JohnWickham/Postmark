FROM swift:5.10.0

RUN apt-get update && apt-get install -y libsqlite3-dev

WORKDIR /postmark
