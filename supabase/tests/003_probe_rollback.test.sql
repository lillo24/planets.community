begin;

select plan(4);

select ok(
  to_regclass('public.planets_security_probe') is null,
  'the probe table was removed by transaction rollback'
);

select ok(
  to_regclass('public.planets_security_probe_id_seq') is null,
  'the probe identity sequence was removed by transaction rollback'
);

select ok(
  to_regclass('public.planets_security_probe_sequence') is null,
  'the explicit probe sequence was removed by transaction rollback'
);

select ok(
  to_regprocedure('public.planets_security_probe_function()') is null,
  'the probe function was removed by transaction rollback'
);

select * from finish();

rollback;
