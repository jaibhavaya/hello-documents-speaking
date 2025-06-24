defmodule HelloDocumentsSpeaking.Models.ConversationMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [inserted_at: :created_at, updated_at: :updated_at]

  @role_user 1
  @role_system 2

  def role_user, do: @role_user
  def role_system, do: @role_system

  schema "conversation_messages" do
    field(:content, :string)
    field(:role, :integer)

    belongs_to(:document_conversation, HelloDocumentsSpeaking.Models.DocumentConversation)

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :role, :document_conversation_id])
    |> validate_required([:content, :role, :document_conversation_id])
    |> validate_inclusion(:role, [@role_user, @role_system])
  end

  # Helper functions to convert between string roles (for API) and integer roles (for DB)
  def string_to_role("user"), do: @role_user
  def string_to_role("assistant"), do: @role_system
  def string_to_role("system"), do: @role_system

  def role_to_string(@role_user), do: "user"
  def role_to_string(@role_system), do: "assistant"
end
