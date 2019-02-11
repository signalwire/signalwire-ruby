# signalwire-client-ruby

This gem provides a client for the Signalwire LAML and REST services.

It supports all of the features in the SignalWire REST API, and generation of LAML responses.

[![Gem Version](https://badge.fury.io/rb/signalwire.svg)](https://badge.fury.io/rb/signalwire)

## Installation

Add `gem 'signalwire'` to your `Gemfile`, or simply `gem install signalwire`.

## SDK Usage

Configure your signalwire subdomain, either by setting the environment variable `SIGNALWIRE_SPACE_URL=your_subdomain.signalwire.com` or within an
initializer:

```ruby
require 'signalwire/sdk'

Signalwire::Sdk.configure do |config|
  config.hostname = "your_subdomain.signalwire.com"
end
```

Then, setup a client to make requests, your `PROJECT_KEY` and `TOKEN` can be found within your Signalwire account, under Settings -> API Credentials

### Making a call

```ruby
@client = Signalwire::REST::Client.new PROJECT_KEY, TOKEN

@call = @client.calls.create(
  from: '+15551234567',
  to: '+15557654321',
  url: "https://cdn.signalwire.com/default-music/playlist.xml",
  method: "GET"
)
```

### Sending a text message

```ruby
@message = @client.messages.create(
  from: '+15551234567',
  to: '+15557654321',
  body: 'This is a message from the Signalwire-Ruby library!'
)
```

## Generating a LAML response

```
require 'signalwire/sdk'

response = Signalwire::Sdk::VoiceResponse.new do |r|
  r.say(message: 'hello there', voice: 'alice')
  r.dial(caller_id: '+14159992222') do |d|
    d.client 'jenny'
  end
end

# print the result
puts response.to_s
```

```
<?xml version="1.0" encoding="UTF-8"?>
<Response>
<Say voice="alice">hello there</Say>
<Dial callerId="+14159992222">
<Client>jenny</Client>
</Dial>
</Response>
```

## Tests

A `Dockerfile` is provided for your testing convenience.

Run `docker run -it $(docker build -q .)` to execute the specs, or `docker run -it $(docker build -q .) sh` to get a shell.

## Contributing to signalwire-client-ruby

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2018 SignalWire Inc. See LICENSE.txt for
further details.
