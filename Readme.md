# Twitter stream csv dumper

    POC Twitter stream listener
    Dumps data to csv from https://dev.twitter.com/docs/api/1.1/post/statuses/filter


## Installation

Clone the repo from github:



And then execute:

    $ bundle


## Usage

    ./dump_statuses.rb --search "bandyou","b-and-you","bouygues","bouyguestelecom","b and you" --languages french,fr,catalan --verbose >> text.csv


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request