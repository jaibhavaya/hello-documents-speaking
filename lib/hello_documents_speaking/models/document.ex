defmodule HelloDocumentsSpeaking.Models.Document do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  require Logger

  schema "base_documents" do
    field(:name, :string)
    field(:file_content_type, :string)
    field(:file_id, :string)
    field(:deleted_at, :naive_datetime)

    belongs_to(:user, HelloDocumentsSpeaking.Models.User)

    timestamps(type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at)
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [:name, :file_content_type, :file_id, :user_id, :deleted_at])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Checks if the document is a PDF file.
  """
  def is_pdf?(%__MODULE__{file_content_type: "application/pdf"}), do: true
  def is_pdf?(_), do: false

  @doc """
  Checks if the document is a folder.
  """
  def is_folder?(%__MODULE__{file_content_type: nil}), do: true
  def is_folder?(_), do: false

  @doc """
  Returns documents that are not folders.
  """
  def files_only(query \\ __MODULE__) do
    from(d in query,
      where: not is_nil(d.file_content_type)
    )
  end

  def pdfs_only(query \\ __MODULE__) do
    from(d in query,
      where: d.file_content_type == "application/pdf"
    )
  end

  def not_deleted(query \\ __MODULE__) do
    from(d in query,
      where: is_nil(d.deleted_at)
    )
  end

  @doc """
  Reads file content from S3 storage using the file_id.

  The file_id should be the S3 key/path to the file.
  Falls back to sample content if S3 reading fails or is not configured.
  """
  def read_file(%__MODULE__{file_id: file_id, name: name}) when not is_nil(file_id) do
    case read_from_s3(file_id) do
      {:ok, content} ->
        Logger.info("Successfully read file from S3: #{name}")
        content

      {:error, reason} ->
        Logger.warning(
          "Failed to read file from S3 (#{reason}), using sample content for #{name}"
        )

        ""
    end
  end

  def read_file(_), do: ""

  defp read_from_s3(file_id) do
    bucket = get_s3_bucket()

    if bucket do
      s3_key = "store/#{file_id}"

      try do
        request = ExAws.S3.get_object(bucket, s3_key)

        case ExAws.request(request) do
          {:ok, %{body: body}} ->
            {:ok, body}

          {:error, {:http_error, 404, _}} ->
            {:error, "File not found in S3"}

          {:error, error} ->
            IO.puts("S3 request failed with error: #{inspect(error)}")
            {:error, "S3 error: #{inspect(error)}"}
        end
      rescue
        e ->
          IO.puts("Exception during S3 request: #{inspect(e)}")
          {:error, "Exception reading from S3: #{inspect(e)}"}
      end
    else
      {:error, "S3 bucket not configured"}
    end
  end

  defp get_s3_bucket do
    Application.get_env(:goose, :s3_bucket)
  end
end
