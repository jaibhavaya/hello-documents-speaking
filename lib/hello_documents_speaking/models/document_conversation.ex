defmodule HelloDocumentsSpeaking.Models.DocumentConversation do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [inserted_at: :created_at, updated_at: :updated_at]

  schema "document_conversations" do
    field(:document_ids, {:array, :integer})

    belongs_to(:user, HelloDocumentsSpeaking.Models.User)

    has_many(:conversation_messages, HelloDocumentsSpeaking.Models.ConversationMessage)

    timestamps()
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:user_id, :document_ids])
    |> validate_required([:user_id, :document_ids])
  end
end
