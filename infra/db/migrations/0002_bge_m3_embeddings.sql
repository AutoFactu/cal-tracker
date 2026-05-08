-- bge-m3 is the active MVP embedding model. It emits 1024-dimensional
-- vectors, so any previous dev embedding rows with a different dimension must
-- be discarded and regenerated.
TRUNCATE TABLE food_memory_embeddings;

ALTER TABLE food_memory_embeddings
  ALTER COLUMN embedding TYPE vector(1024);

DELETE FROM embedding_models
WHERE provider <> 'local'
   OR model <> 'bge-m3'
   OR dimensions <> 1024;

INSERT INTO embedding_models (provider, model, dimensions)
SELECT 'local', 'bge-m3', 1024
WHERE NOT EXISTS (
  SELECT 1 FROM embedding_models
  WHERE provider = 'local'
    AND model = 'bge-m3'
    AND dimensions = 1024
);
