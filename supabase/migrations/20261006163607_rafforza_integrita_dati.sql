-- ============================================================
-- LA PALEXTRA
-- Migration: rafforzamento integrità dati
-- ============================================================


-- ============================================================
-- 1. IMPOSTAZIONI PALESTRA
--    Deve esistere una sola configurazione.
-- ============================================================

create unique index if not exists uq_impostazioni_palestra_unica
    on public.impostazioni_palestra ((true));


-- ============================================================
-- 2. CERTIFICATI MEDICI
--    Il percorso del file deve essere univoco.
-- ============================================================

create unique index if not exists uq_certificati_medici_percorso
    on public.certificati_medici (percorso_archiviazione);


-- ============================================================
-- 3. ISTRUTTORE CORSO
--    Verifica che il profilo associato abbia il ruolo
--    ISTRUTTORE.
-- ============================================================

create or replace function public.verifica_istruttore_corso()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

    if not exists (
        select 1
        from public.ruoli_utenti ru
        join public.ruoli r
            on r.id = ru.ruolo_id
        where ru.utente_id = new.istruttore_id
          and r.codice = 'ISTRUTTORE'
    ) then
        raise exception
            'Il profilo % non possiede il ruolo ISTRUTTORE',
            new.istruttore_id;
    end if;

    return new;

end;
$$;


drop trigger if exists trg_verifica_istruttore_corso
    on public.istruttori_corso;

create trigger trg_verifica_istruttore_corso
before insert or update on public.istruttori_corso
for each row
execute function public.verifica_istruttore_corso();


-- ============================================================
-- 4. ISCRIZIONE SEZIONE
--    La sezione deve appartenere allo stesso corso
--    dell'iscrizione.
-- ============================================================

create or replace function public.verifica_iscrizione_sezione()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_corso_iscrizione uuid;
    v_corso_sezione uuid;
begin

    select corso_id
      into v_corso_iscrizione
      from public.iscrizioni_corso
     where id = new.iscrizione_corso_id;

    select corso_id
      into v_corso_sezione
      from public.sezioni_corso
     where id = new.sezione_corso_id;

    if v_corso_iscrizione is null then
        raise exception
            'Iscrizione corso % inesistente',
            new.iscrizione_corso_id;
    end if;

    if v_corso_sezione is null then
        raise exception
            'Sezione corso % inesistente',
            new.sezione_corso_id;
    end if;

    if v_corso_iscrizione <> v_corso_sezione then
        raise exception
            'La sezione % non appartiene al corso dell''iscrizione',
            new.sezione_corso_id;
    end if;

    return new;

end;
$$;


drop trigger if exists trg_verifica_iscrizione_sezione
    on public.iscrizioni_sezione;

create trigger trg_verifica_iscrizione_sezione
before insert or update on public.iscrizioni_sezione
for each row
execute function public.verifica_iscrizione_sezione();


-- ============================================================
-- 5. ISCRIZIONI CORSO
--    Lo stesso atleta non può avere periodi sovrapposti
--    sullo stesso corso.
-- ============================================================

create or replace function public.verifica_sovrapposizione_iscrizione()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

    if exists (
        select 1
        from public.iscrizioni_corso ic
        where ic.atleta_id = new.atleta_id
          and ic.corso_id = new.corso_id
          and ic.id <> new.id
          and daterange(
                ic.data_inizio,
                ic.data_fine,
                '[]'
              )
              &&
              daterange(
                new.data_inizio,
                new.data_fine,
                '[]'
              )
    ) then

        raise exception
            'Esiste già un''iscrizione sovrapposta per atleta % e corso %',
            new.atleta_id,
            new.corso_id;

    end if;

    return new;

end;
$$;


drop trigger if exists trg_verifica_sovrapposizione_iscrizione
    on public.iscrizioni_corso;

create trigger trg_verifica_sovrapposizione_iscrizione
before insert or update on public.iscrizioni_corso
for each row
execute function public.verifica_sovrapposizione_iscrizione();


-- ============================================================
-- 6. PRESENZE
--    Verifica che l'atleta:
--      - sia iscritto al corso;
--      - sia associato alla sezione della lezione;
--      - sia coperto dalla data dell'iscrizione.
-- ============================================================

create or replace function public.verifica_presenza_coerente()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_corso_id uuid;
    v_data_lezione date;
begin

    select
        sc.corso_id,
        l.data_lezione
    into
        v_corso_id,
        v_data_lezione
    from public.lezioni l
    join public.sezioni_corso sc
        on sc.id = l.sezione_corso_id
    where l.id = new.lezione_id;

    if v_corso_id is null then
        raise exception
            'Lezione % inesistente',
            new.lezione_id;
    end if;


    if not exists (
        select 1
        from public.iscrizioni_corso ic
        join public.iscrizioni_sezione isec
            on isec.iscrizione_corso_id = ic.id
        join public.lezioni l
            on l.sezione_corso_id = isec.sezione_corso_id
        where ic.atleta_id = new.atleta_id
          and ic.corso_id = v_corso_id
          and isec.sezione_corso_id = l.sezione_corso_id
          and l.id = new.lezione_id
          and ic.stato in ('ATTIVA', 'SOSPESA')
          and v_data_lezione between ic.data_inizio and ic.data_fine
    ) then

        raise exception
            'L''atleta % non è iscritto alla sezione della lezione %',
            new.atleta_id,
            new.lezione_id;

    end if;

    return new;

end;
$$;


drop trigger if exists trg_verifica_presenza_coerente
    on public.presenze;

create trigger trg_verifica_presenza_coerente
before insert or update on public.presenze
for each row
execute function public.verifica_presenza_coerente();


-- ============================================================
-- 7. PAGAMENTI
--    Verifica che il pagamento appartenga allo stesso atleta
--    della rata/quota e che non superi l'importo dovuto.
--
--    Sono consentiti pagamenti parziali.
-- ============================================================

create or replace function public.verifica_pagamento()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_atleta_id uuid;
    v_importo_dovuto numeric;
    v_pagamenti_esistenti numeric;
begin

    -- --------------------------------------------------------
    -- Pagamento collegato a una rata abbonamento
    -- --------------------------------------------------------

    if new.rata_abbonamento_id is not null then

        select
            a.atleta_id,
            r.importo_finale
        into
            v_atleta_id,
            v_importo_dovuto
        from public.rate_abbonamento r
        join public.abbonamenti a
            on a.id = r.abbonamento_id
        where r.id = new.rata_abbonamento_id;

        if v_atleta_id is null then
            raise exception
                'Rata abbonamento % inesistente',
                new.rata_abbonamento_id;
        end if;

        if v_atleta_id <> new.atleta_id then
            raise exception
                'Il pagamento non appartiene all''atleta associato alla rata';
        end if;

        select coalesce(sum(p.importo), 0)
          into v_pagamenti_esistenti
          from public.pagamenti p
         where p.rata_abbonamento_id = new.rata_abbonamento_id
           and p.id <> new.id;

        if v_pagamenti_esistenti + new.importo > v_importo_dovuto then
            raise exception
                'Il pagamento supera l''importo residuo della rata';
        end if;

    end if;


    -- --------------------------------------------------------
    -- Pagamento collegato a quota iscrizione
    -- --------------------------------------------------------

    if new.quota_iscrizione_id is not null then

        select
            qi.atleta_id,
            qi.importo
        into
            v_atleta_id,
            v_importo_dovuto
        from public.quote_iscrizione qi
        where qi.id = new.quota_iscrizione_id;

        if v_atleta_id is null then
            raise exception
                'Quota iscrizione % inesistente',
                new.quota_iscrizione_id;
        end if;

        if v_atleta_id <> new.atleta_id then
            raise exception
                'Il pagamento non appartiene all''atleta associato alla quota';
        end if;

        select coalesce(sum(p.importo), 0)
          into v_pagamenti_esistenti
          from public.pagamenti p
         where p.quota_iscrizione_id = new.quota_iscrizione_id
           and p.id <> new.id;

        if v_pagamenti_esistenti + new.importo > v_importo_dovuto then
            raise exception
                'Il pagamento supera l''importo residuo della quota iscrizione';
        end if;

    end if;


    return new;

end;
$$;


drop trigger if exists trg_verifica_pagamento
    on public.pagamenti;

create trigger trg_verifica_pagamento
before insert or update on public.pagamenti
for each row
execute function public.verifica_pagamento();


-- ============================================================
-- 8. NOTIFICHE
--    Se una notifica è INVIATA deve avere la data di invio.
-- ============================================================

alter table public.notifiche
drop constraint if exists chk_notifiche_data_invio;

alter table public.notifiche
add constraint chk_notifiche_data_invio
check (
    stato <> 'INVIATA'
    or data_invio is not null
);


-- ============================================================
-- 9. PAGAMENTI
--    L'importo deve essere positivo.
--    Il vincolo esiste già nello schema iniziale, ma viene
--    ribadito solo se non presente.
-- ============================================================

alter table public.pagamenti
drop constraint if exists chk_pagamenti_importo;

alter table public.pagamenti
add constraint chk_pagamenti_importo
check (importo > 0);


-- ============================================================
-- 10. PROTEZIONE FUNZIONI DI SICUREZZA
--     Le funzioni SECURITY DEFINER non devono essere
--     eseguibili anonimamente.
-- ============================================================

revoke execute
on function public.verifica_istruttore_corso()
from public;

revoke execute
on function public.verifica_iscrizione_sezione()
from public;

revoke execute
on function public.verifica_sovrapposizione_iscrizione()
from public;

revoke execute
on function public.verifica_presenza_coerente()
from public;

revoke execute
on function public.verifica_pagamento()
from public;