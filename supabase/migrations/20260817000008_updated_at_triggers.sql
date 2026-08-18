-- Keep updated_at (and version, used for simple last-write-wins conflict
-- handling per spec 9.4) current on every row update.

create function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  new.version := coalesce(old.version, 0) + 1;
  return new;
end;
$$;

create trigger purchases_set_updated_at
  before update on public.purchases
  for each row execute function public.set_updated_at();

-- items/warranties don't carry a version column (only purchases needs
-- conflict versioning today per spec 21), so use a lighter trigger for them.
create function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger items_touch_updated_at
  before update on public.items
  for each row execute function public.touch_updated_at();

create trigger warranties_touch_updated_at
  before update on public.warranties
  for each row execute function public.touch_updated_at();
