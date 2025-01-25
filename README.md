# DeepL.cr

[![CI](https://github.com/kojix2/deepl.cr/actions/workflows/ci.yml/badge.svg)](https://github.com/kojix2/deepl.cr/actions/workflows/ci.yml)
[![Docs Latest](https://img.shields.io/badge/docs-latest-blue.svg)](https://kojix2.github.io/deepl.cr/)

Crystal library for the [DeepL language translation API](https://www.deepl.com/pro-api/).

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

# Translate text
t = DeepL::Translator.new(auth_key: "YOUR_AUTH_KEY")
puts t.translate_text("こんにちは、世界！", target_lang: "EN") # => "Hello, world!"

# Translate document
t = DeepL::Translator.new(auth_key: "YOUR_AUTH_KEY")
puts t.translate_document("path/to/document.pdf", target_lang: "EN")
# Save to file (default: "path/to/document_EN.pdf")
```

See [documentation](https://kojix2.github.io/deepl.cr/).

### Environment Variables

<table>
  <thead>
    <tr>
      <th>Name</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>DEEPL_AUTH_KEY</td>
      <td>DeepL API authentication key</td>
    </tr>
    <tr>
      <td>DEEPL_TARGET_LANG</td>
      <td>Default target language</td>
    </tr>
    <tr>
      <td>DEEPL_USER_AGENT</td>
      <td>User-Agent</td>
    </tr>
  </tbody>
</table>

- When the environment variable `DEEPL_TARGET_LANG` is set, the method `DeepL::Translator#guess_target_language` will prioritize the language defined in `DEEPL_TARGET_LANG`. 
- However, please note that this does not directly affect translation methods like `translate_text`.

## Development

- Pull requests are welcome.
- If you want to take over the project and become the owner, please submit your request with a pull request.

## Use case

- [DeepL CLI](https://github.com/kojix2/deepl-cli)

## Contributing

1. Fork it (<https://github.com/kojix2/deepl.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

# License

MIT
