defmodule HelloDocumentsSpeaking.Services.PDFExtractor do
  @moduledoc """
  PDF text extraction utilities.

  Uses MuPDF via command line interface.
  Requires MuPDF to be installed on the system.
  """

  require Logger

  @doc """
  Extracts text from a PDF file.

  ## Parameters
  - `file_path`: Path to the PDF file on disk

  ## Returns
  - String containing extracted text on success
  - Empty string on failure
  """
  def extract_text(file_path) when is_binary(file_path) do
    if File.exists?(file_path) do
      extract_with_mupdf(file_path)
    else
      Logger.error("PDF file not found: #{file_path}")
      ""
    end
  end

  def extract_text(_), do: ""

  @doc """
  Extracts text from PDF binary content by writing to a temporary file.

  ## Parameters
  - `pdf_binary`: Binary content of the PDF file

  ## Returns
  - String containing extracted text on success
  - Empty string on failure
  """
  def extract_text_from_binary(pdf_binary) when is_binary(pdf_binary) do
    temp_path = create_temp_file(pdf_binary)

    try do
      extract_text(temp_path)
    after
      File.rm(temp_path)
    end
  end

  def extract_text_from_binary(_), do: ""

  defp extract_with_mupdf(file_path) do
    try do
      case System.cmd("mutool", ["draw", "-F", "txt", file_path], stderr_to_stdout: true) do
        {output, 0} ->
          cleaned = clean_extracted_text(output)

          if String.trim(cleaned) != "" do
            cleaned
          else
            ""
          end

        {error_output, exit_code} ->
          Logger.error(
            "MuPDF standard extraction failed (exit code #{exit_code}): #{error_output}"
          )

          ""
      end
    rescue
      e ->
        Logger.error("MuPDF extraction error: #{inspect(e)}")
        ""
    end
  end

  defp create_temp_file(binary_content) do
    temp_dir = System.tmp_dir!()
    temp_filename = "pdf_extract_#{:rand.uniform(999_999)}.pdf"
    temp_path = Path.join(temp_dir, temp_filename)

    File.write!(temp_path, binary_content)

    temp_path
  end

  defp clean_extracted_text(text) do
    text
    # Normalize line endings
    |> String.replace(~r/\r\n|\r|\n/, " ")
    # Collapse multiple spaces
    |> String.replace(~r/\s+/, " ")
    # Remove leading/trailing whitespace
    |> String.trim()
  end

  @doc """
  Checks if MuPDF is available on the system.

  ## Returns
  - `true` if MuPDF is available
  - `false` if MuPDF is not found
  """
  def mupdf_available? do
    case System.cmd("which", ["mutool"], stderr_to_stdout: true) do
      {_output, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end
end

