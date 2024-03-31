# DeepL.cr

[![CI](https://github.com/kojix2/deepl.cr/actions/workflows/ci.yml/badge.svg)](https://github.com/kojix2/deepl.cr/actions/workflows/ci.yml)

Crystal library for the DeepL language translation API. 

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     deepl:
       github: kojix2/deepl
   ```

2. Run `shards install`

## Usage

```crystal
require "deepl"
```

## Development

- Pull requests are welcome.
- If you want to take over the project and become the owner, please submit your request with a pull request.
- In a small community like Crystal, OSS developers have limited time to devote to coding. To maintain flexibility for future API changes, do not try to parse `JSON::Any` into Hash objects more than necessary. While far from ideal, there are real advantages. 

## Contributing

1. Fork it (<https://github.com/kojix2/deepl/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

# License

MIT
