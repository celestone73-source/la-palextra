-- ============================================================
-- LA PALEXTRA
-- Migration: notifiche, dispositivi, audit e impostazioni
-- ============================================================


-- ============================================================
-- NOTIFICHE
-- ============================================================

create table public.notifiche (
    id uuid primary key default gen_random_uuid(),

    utente_id uuid not null
        references public.profili(id) on delete restrict,

    tipo text not null
        check (tipo in (
            'LEZIONE_IN_ARRIVO',
            'CERTIFICATO_IN_SCADENZA',
            'LEZIONE_ANNULLATA',
            'ISCRIZIONE_CONFERMATA'
        )),

    titolo text not null,
    messaggio text not null,

    data_programmata timestamptz,
    data_invio timestamptz,

    stato text not null default 'PROGRAMMATA'
        check (stato in (
            'PROGRAMMATA',
            'INVIATA',
            'ERRORE',
            'ANNULLATA'
        )),

    data_creazione timestamptz not null default now()
);

create index idx_notifiche_utente
    on public.notifiche (utente_id);

create index idx_notifiche_stato
    on public.notifiche (stato);

create index idx_notifiche_data_programmata
    on public.notifiche (data_programmata);


-- ============================================================
-- DISPOSITIVI PUSH
-- ============================================================

create table public.dispositivi_push (
    id uuid primary key default gen_random_uuid(),

    utente_id uuid not null
        references public.profili(id) on delete cascade,

    token text not null,

    piattaforma text not null
        check (piattaforma in (
            'WEB',
            'ANDROID',
            'IOS'
        )),

    attivo boolean not null default true,

    data_creazione timestamptz not null default now(),
    data_modifica timestamptz not null default now(),

    constraint uq_dispositivo_token
        unique (token)
);

create index idx_dispositivi_push_utente
    on public.dispositivi_push (utente_id);

create index idx_dispositivi_push_attivo
    on public.dispositivi_push (attivo);


-- ============================================================
-- REGISTRO ACCESSI / AUDIT
-- ============================================================

create table public.registri_accesso (
    id uuid primary key default gen_random_uuid(),

    utente_id uuid
        references public.profili(id) on delete restrict,

    azione text not null,

    tabella text not null,

    record_id uuid,

    dati_precedenti jsonb,
    dati_nuovi jsonb,

    data_creazione timestamptz not null default now()
);

create index idx_registri_accesso_utente
    on public.registri_accesso (utente_id);

create index idx_registri_accesso_tabella
    on public.registri_accesso (tabella);

create index idx_registri_accesso_record
    on public.registri_accesso (record_id);

create index idx_registri_accesso_data
    on public.registri_accesso (data_creazione);


-- ============================================================
-- IMPOSTAZIONI PALESTRA
--
-- Inizialmente la tabella conterrà una sola riga.
-- Il vincolo applicativo verrà gestito successivamente.
-- ============================================================

create table public.impostazioni_palestra (
    id uuid primary key default gen_random_uuid(),

    nome_palestra text not null,
    indirizzo text,
    telefono text,
    email text,
    sito_web text,
    logo text,

    data_modifica timestamptz not null default now()
);


-- ============================================================
-- RLS
-- ============================================================

alter table public.notifiche enable row level security;
alter table public.dispositivi_push enable row level security;
alter table public.registri_accesso enable row level security;
alter table public.impostazioni_palestra enable row level security;