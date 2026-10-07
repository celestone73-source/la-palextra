-- ============================================================
-- LA PALEXTRA
-- Migration: anagrafiche e sicurezza
-- ============================================================

-- ============================================================
-- PROFILI
-- Collegamento 1:1 con auth.users
-- ============================================================

create table public.profili (
    id uuid primary key references auth.users(id) on delete restrict,
    nome text not null,
    cognome text not null,
    email text,
    telefono text,
    data_creazione timestamptz not null default now(),
    data_modifica timestamptz not null default now()
);

-- ============================================================
-- ATLETI
-- ============================================================

create table public.atleti (
    id uuid primary key default gen_random_uuid(),

    profilo_id uuid not null unique
        references public.profili(id) on delete restrict,

    data_nascita date,
    codice_fiscale text,
    indirizzo text,
    nome_contatto_emergenza text,
    telefono_contatto_emergenza text,

    data_iscrizione date not null default current_date,

    stato text not null default 'ATTIVO'
        check (stato in ('ATTIVO', 'INATTIVO')),

    note text,

    data_creazione timestamptz not null default now(),
    data_modifica timestamptz not null default now()
);

-- Codice fiscale univoco solo quando valorizzato
create unique index uq_atleti_codice_fiscale
    on public.atleti (codice_fiscale)
    where codice_fiscale is not null;


-- ============================================================
-- RUOLI
-- ============================================================

create table public.ruoli (
    id uuid primary key default gen_random_uuid(),

    codice text not null unique,
    nome text not null,
    descrizione text,

    data_creazione timestamptz not null default now()
);

-- ============================================================
-- PERMESSI
-- ============================================================

create table public.permessi (
    id uuid primary key default gen_random_uuid(),

    codice text not null unique,
    nome text not null,
    descrizione text,

    data_creazione timestamptz not null default now()
);

-- ============================================================
-- RUOLI UTENTI
-- ============================================================

create table public.ruoli_utenti (
    utente_id uuid not null
        references public.profili(id) on delete restrict,

    ruolo_id uuid not null
        references public.ruoli(id) on delete restrict,

    data_creazione timestamptz not null default now(),

    primary key (utente_id, ruolo_id)
);

-- ============================================================
-- PERMESSI RUOLI
-- ============================================================

create table public.permessi_ruoli (
    ruolo_id uuid not null
        references public.ruoli(id) on delete restrict,

    permesso_id uuid not null
        references public.permessi(id) on delete restrict,

    data_creazione timestamptz not null default now(),

    primary key (ruolo_id, permesso_id)
);


-- ============================================================
-- FAMIGLIE
-- ============================================================

create table public.famiglie (
    id uuid primary key default gen_random_uuid(),

    nome text not null,

    data_creazione timestamptz not null default now()
);

-- ============================================================
-- MEMBRI FAMIGLIA
-- ============================================================

create table public.membri_famiglia (
    famiglia_id uuid not null
        references public.famiglie(id) on delete cascade,

    atleta_id uuid not null
        references public.atleti(id) on delete restrict,

    relazione text,

    data_creazione timestamptz not null default now(),

    primary key (famiglia_id, atleta_id)
);

create index idx_membri_famiglia_atleta
    on public.membri_famiglia (atleta_id);


-- ============================================================
-- CERTIFICATI MEDICI
-- ============================================================

create table public.certificati_medici (
    id uuid primary key default gen_random_uuid(),

    atleta_id uuid not null
        references public.atleti(id) on delete restrict,

    percorso_archiviazione text not null,
    nome_file_originale text not null,
    tipo_mime text not null,
    dimensione_file bigint not null
        check (dimensione_file >= 0),

    data_rilascio date not null,
    data_inizio_validita date not null,
    data_scadenza date not null,

    data_caricamento timestamptz not null default now(),

    constraint chk_certificati_date
        check (data_scadenza >= data_inizio_validita)
);

create index idx_certificati_medici_atleta
    on public.certificati_medici (atleta_id);

create index idx_certificati_medici_scadenza
    on public.certificati_medici (data_scadenza);


-- ============================================================
-- TESSERE MSP
-- ============================================================

create table public.tessere_msp (
    id uuid primary key default gen_random_uuid(),

    atleta_id uuid not null
        references public.atleti(id) on delete restrict,

    numero_tessera text not null,
    anno integer not null,

    data_inizio_validita date not null,
    data_scadenza date not null,

    stato text not null
        check (stato in ('ATTIVA', 'SCADUTA', 'ANNULLATA')),

    note text,

    data_creazione timestamptz not null default now(),
    data_modifica timestamptz not null default now(),

    constraint chk_tessere_msp_date
        check (data_scadenza >= data_inizio_validita),

    constraint uq_tessere_msp_atleta_anno
        unique (atleta_id, anno),

    constraint uq_tessere_msp_numero
        unique (numero_tessera)
);

create index idx_tessere_msp_atleta
    on public.tessere_msp (atleta_id);


-- ============================================================
-- ASSICURAZIONI
-- ============================================================

create table public.assicurazioni (
    id uuid primary key default gen_random_uuid(),

    atleta_id uuid not null
        references public.atleti(id) on delete restrict,

    anno integer not null,

    data_inizio_validita date not null,
    data_scadenza date not null,

    numero_polizza text,

    stato text not null
        check (stato in ('ATTIVA', 'SCADUTA', 'ANNULLATA')),

    note text,

    data_creazione timestamptz not null default now(),
    data_modifica timestamptz not null default now(),

    constraint chk_assicurazioni_date
        check (data_scadenza >= data_inizio_validita),

    constraint uq_assicurazioni_atleta_anno
        unique (atleta_id, anno)
);

create index idx_assicurazioni_atleta
    on public.assicurazioni (atleta_id);


-- ============================================================
-- RLS
-- Per ora abilitiamo RLS.
-- Le policy dettagliate verranno create nella migration
-- dedicata alla sicurezza.
-- ============================================================

alter table public.profili enable row level security;
alter table public.atleti enable row level security;
alter table public.ruoli enable row level security;
alter table public.permessi enable row level security;
alter table public.ruoli_utenti enable row level security;
alter table public.permessi_ruoli enable row level security;
alter table public.famiglie enable row level security;
alter table public.membri_famiglia enable row level security;
alter table public.certificati_medici enable row level security;
alter table public.tessere_msp enable row level security;
alter table public.assicurazioni enable row level security;