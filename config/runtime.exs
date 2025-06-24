import Config
import Dotenvy

source!([
  Path.absname(".env"),
  System.get_env()
])

config :hello_documents_speaking, HelloDocumentsSpeaking.Repo,
  database: env!("DATABASE_NAME", :string!),
  username: env!("DATABASE_USER", :string!),
  password: env!("DATABASE_PASSWORD", :string!),
  hostname: env!("DATABASE_HOST", :string!),
  port: env!("DATABASE_PORT", :string!)

config :hello_documents_speaking,
  openai_api_key: env!("OPENAI_API_KEY"),
  s3_bucket: env!("AWS_S3_BUCKET")

aws_region = env!("AWS_REGION", :string!)
access_key = env!("AWS_ACCESS_KEY_ID", :string!)
secret_access_key = env!("AWS_SECRET_ACCESS_KEY", :string!)
host = "s3.#{aws_region}.amazonaws.com"
bucket = env!("AWS_S3_BUCKET", :string!)

IO.puts("region: #{aws_region}")
IO.puts("key: #{access_key}")
IO.puts("access_key: #{secret_access_key}")
IO.puts("host: #{host}")
IO.puts("bucket: #{bucket}")

config :ex_aws,
  access_key_id: env!("AWS_ACCESS_KEY_ID", :string!),
  secret_access_key: env!("AWS_SECRET_ACCESS_KEY", :string!),
  region: aws_region

config :ex_aws, :s3,
  scheme: "https://",
  region: aws_region
