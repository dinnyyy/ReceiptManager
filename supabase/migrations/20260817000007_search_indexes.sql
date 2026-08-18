-- Full-text search (spec 5.10, 10.4): search structured fields plus raw OCR
-- text and linked item name/model/serial. Generated columns keep the vector
-- in sync automatically; a GIN index makes it fast.

alter table public.purchases
  add column search_vector tsvector
  generated always as (
    setweight(to_tsvector('english', coalesce(merchant_name, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(receipt_number, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(notes, '')), 'C') ||
    setweight(to_tsvector('english', coalesce(raw_ocr_text, '')), 'D')
  ) stored;

create index purchases_search_vector_idx on public.purchases using gin (search_vector);

alter table public.items
  add column search_vector tsvector
  generated always as (
    setweight(to_tsvector('english', coalesce(name, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(brand, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(model, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(serial_number, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(location, '')), 'C') ||
    setweight(to_tsvector('english', coalesce(notes, '')), 'C')
  ) stored;

create index items_search_vector_idx on public.items using gin (search_vector);
