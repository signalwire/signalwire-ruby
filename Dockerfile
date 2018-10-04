FROM ruby:latest

COPY . /app
WORKDIR /app

RUN bundle install
CMD ["bundle", "exec", "rspec"]

