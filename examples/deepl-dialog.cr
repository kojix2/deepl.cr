# deepl-dialog.rb
# This script is a simple GUI wrapper around the DeepL API for translating documents.
# It uses Powershell to show dialogs and to select files.

# ## Windows Only

{% unless flag?(:windows) %}
  puts "This program is only supported on Windows."
  exit(0)
{% end %}

require "json"
require "../src/deepl"

# ## Powershell GUI Dialogs

def powershell_run_script(script : String) : String
  powershell_script = <<-POWERSHELL
  powershell -Command
    #{script}
  POWERSHELL
  ps = Process.new(
    command: powershell_script,
    output: Process::Redirect::Pipe,
    error: Process::Redirect::Pipe,
    shell: true
  )
  stdout = ps.output.gets_to_end.strip
  stderr = ps.error.gets_to_end.strip
  ps.wait
  STDERR.puts(stderr) unless stderr.empty?
  stdout
end

def powershell_show_message_dialog(
  message : String,
  title : String,
  icon : String = "Information"
)
  cmd = <<-POWERSHELL
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
      \\"#{message}\\", \\"#{title}\\",
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::#{icon}
    )
  POWERSHELL
  powershell_run_script(cmd)
end

def powershell_entry_for_api_key
  input_dialog_cmd = <<-POWERSHELL
      Add-Type -AssemblyName Microsoft.VisualBasic
      Add-Type -AssemblyName System.Windows.Forms
      $apiKey = [Microsoft.VisualBasic.Interaction]::InputBox(\\"Enter your DeepL API Key:\\", \\"API Key\\", \\"\\")
      Write-Host $apiKey
  POWERSHELL
  powershell_run_script(input_dialog_cmd)
end

private def valid_filetypes_for_deepl_document_translation
  {
    "All Files"                => "*.*",
    "Word Documents"           => "*.docx",
    "PowerPoint Presentations" => "*.pptx",
    "Excel Workbooks"          => "*.xlsx",
    "PDF Files"                => "*.pdf",
    "HTML Documents"           => "*.htm;*.html",
    "Text Files"               => "*.txt",
    "XLIFF Documents"          => "*.xlf;*.xliff",
  }
end

private def filter_string_for_select_file_dialog
  valid_filetypes_for_deepl_document_translation.map do |d, e|
    "#{d} (#{e})|#{e}"
  end.join("|")
end

def powershell_select_file_dialog
  filter_string = filter_string_for_select_file_dialog

  cmd = <<-POWERSHELL
    Add-Type -AssemblyName System.Windows.Forms
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.filter = \\"#{filter_string}\\"
    $openFileDialog.ShowDialog() > $null
    Write-Host $openFileDialog.Filename
  POWERSHELL

  path = powershell_run_script(cmd)
  Path.windows(path)
end

# ## Deepl API Key Management

def config_json_file_path : Path
  Path["config.json"].expand
end

def get_api_key_from_config_file : String?
  if File.exists?(config_json_file_path)
    config = JSON.parse(File.read(config_json_file_path))
    key = config["deepl_api_key"]?
    key.nil? ? nil : key.to_s
  end
end

def save_api_key_to_config_file(api_key : String)
  config = {"deepl_api_key" => api_key}
  File.write("config.json", config.to_json)
end

def delete_config_file_and_exit
  File.delete(config_json_file_path) if File.exists?(config_json_file_path)
  powershell_show_message_dialog(
    message: "The API Key stored in the configuration file has been deleted due to authorization failure. \n" \
             "Please restart the application and enter a valid API Key.",
    title: "API Key Error",
    icon: "Warning"
  )
  exit(1)
end

def call_deepl_api_get_usage(key)
  t = DeepL::Translator.new(auth_key: key)
  t.get_usage
end

def check_deepl_auth_key_is_valid(key)
  begin
    call_deepl_api_get_usage(key)
  rescue ex : Crest::RequestFailed
    delete_config_file_and_exit
  end
end

def create_config_file
  api_key = powershell_entry_for_api_key

  # Cancelled
  if api_key.empty?
    powershell_show_message_dialog("No API Key provided.", "NO API KEY")
    exit(0)
  end

  save_api_key_to_config_file(api_key)
  powershell_show_message_dialog(
    message: "API Key saved successfully.",
    title: "API Key Saved"
  )
end

def setup_deepl_api_key
  key = get_api_key_from_config_file
  if key
    usage = check_deepl_auth_key_is_valid(key)
  else
    create_config_file
    # NOTE: Recursive call to get the key from the config file
    key, usage = setup_deepl_api_key
  end
  {key, usage}
end

# ## Main Program

def main
  key, usage = setup_deepl_api_key

  if ARGV.size > 0
    path = Path.windows(ARGV[0])
  else
    path = powershell_select_file_dialog
    exit(0) if path == Path[""] # Cancelled
  end

  translator = DeepL::Translator.new

  translator.translate_document(
    path: path, target_lang: translator.guess_target_language
  )

  # TODO : Add a message dialog to show the translation usage for the document

  powershell_show_message_dialog(
    message: "Translation completed successfully\n#{translator.get_usage}",
    title: "Success"
  )
rescue ex
  handle_error(ex)
  exit(1)
end

private def handle_error(ex)
  error_message = "ERROR: #{ex.class} #{ex.message}"
  error_message += "\n#{ex.response}" if ex.is_a?(Crest::RequestFailed)

  powershell_show_message_dialog(error_message, "Error")

  delete_config_file_and_exit if ex.is_a?(Crest::Forbidden)
end

main()
