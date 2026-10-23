// Only table/column identities, counts and digests leave PostgreSQL. Original
// Auth/profile/Storage values are never transferred to the writer or artifacts.
const quote = (value) => '"' + value.replaceAll('"', '""') + '"';
export async function preservationTables(sql) {
  return sql`select n.nspname schema,c.relname name,array_agg(a.attname order by a.attnum) columns
    from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid
    where n.nspname in ('public','private','auth','storage') and c.relkind in ('r','p') and a.attnum>0 and not a.attisdropped
    group by n.nspname,c.relname order by n.nspname,c.relname`;
}
export async function preservationSnapshot(sql, tables) {
  const rows = [];
  for (const t of tables) {
    const [row] = await sql.unsafe(`select count(*)::bigint::text count,
      md5(coalesce(string_agg(row_to_json(t)::text,E'\\n' order by row_to_json(t)::text),'')) digest
      from (select ${t.columns.map(quote).join(",")} from ${quote(t.schema)}.${quote(t.name)}) t`);
    rows.push({ table: t.schema + "." + t.name, ...row });
  }
  return rows;
}
