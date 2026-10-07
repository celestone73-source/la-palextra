-- ============================================================
-- LA PALEXTRA
-- Migration: corsi, lezioni e presenze
-- ============================================================


-- ============================================================
-- CORSI
-- ============================================================

create table public.corsi (
    id uuid primary key default gen_random_uuid(),

    nome text not null,
    descrizione text,

    stato text not null default 'ATTIVO'
        check (stato in ('ATTIVO', 'INATTIVO')),

    data_creazione timestamptz not null default now(),
    data_modifica timestamptz not null default now()
);


-- ============================================================
-- ISTRUTTORI CORSO
-- Associa uno o più istruttori a un corso.
-- ============================================================

create table public.istruttori_corso (
    corso_id uuid not null
        references public.corsi(id) on delete restrict,

    istruttore_id uuid not null
        references public.profili(id) on delete restrict,

    data_creazione timestamptz not null default now(),

    primary key (corso_id, istruttore_id)
);

create index idx_istruttori_corso_istruttore
    on public.istruttori_corso (istruttore_id);


-- ============================================================
-- SEZIONI CORSO
--
-- Rappresentano l'orario ricorrente del corso.
--
-- giorno_settimana:
-- 1 = lunedì
-- 2 = martedì
-- 3 = mercoledì
-- 4 = giovedì
-- 5 = venerdì
-- 6 = sabato
-- 7 = domenica
-- ============================================================

create table public.sezioni_corso (
    id uuid primary key default gen_random_uuid(),

    corso_id uuid not null
        references public.corsi(id) on delete restrict,

    giorno_settimana smallint not null
        check (giorno_settimana between 1 and 7),

    ora_inizio time not null,
    ora_fine time not null,

    sala text,

    capacita integer
        check (capacita is null or capacita > 0),

    attivo boolean not null default true,

    data_creazione timestamptz not null default now(),
    data_modifica timestamptz not null default now(),

    constraint chk_sezione_orario
        check (ora_fine > ora_inizio)
);

create index idx_sezioni_corso_corso
    on public.sezioni_corso (corso_id);

create index idx_sezioni_corso_giorno
    on public.sezioni_corso (giorno_settimana);


-- ============================================================
-- ISCRIZIONI CORSO
--
-- L'atleta si iscrive al corso per un determinato periodo.
-- Non viene effettuata una prenotazione per ogni singola lezione.
-- ============================================================

create table public.iscrizioni_corso (
    id uuid primary key default gen_random_uuid(),

    corso_id uuid not null
        references public.corsi(id) on delete restrict,

    atleta_id uuid not null
        references public.atleti(id) on delete restrict,

    data_inizio date not null,
    data_fine date not null,

    stato text not null default 'ATTIVA'
        check (stato in ('ATTIVA', 'SOSPESA', 'TERMINATA')),

    data_creazione timestamptz not null default now(),
    data_modifica timestamptz not null default now(),

    constraint chk_iscrizione_corso_date
        check (data_fine >= data_inizio)
);

create index idx_iscrizioni_corso_corso
    on public.iscrizioni_corso (corso_id);

create index idx_iscrizioni_corso_atleta
    on public.iscrizioni_corso (atleta_id);

create index idx_iscrizioni_corso_periodo
    on public.iscrizioni_corso (data_inizio, data_fine);


-- ============================================================
-- ISCRIZIONI SEZIONE
--
-- Collega l'iscrizione annuale dell'atleta alle sezioni
--/orari che frequenta.
-- ============================================================

create table public.iscrizioni_sezione (
    iscrizione_corso_id uuid not null
        references public.iscrizioni_corso(id) on delete cascade,

    sezione_corso_id uuid not null
        references public.sezioni_corso(id) on delete restrict,

    data_creazione timestamptz not null default now(),

    primary key (iscrizione_corso_id, sezione_corso_id)
);

create index idx_iscrizioni_sezione_sezione
    on public.iscrizioni_sezione (sezione_corso_id);


-- ============================================================
-- LEZIONI
--
-- Rappresentano le singole lezioni effettivamente generate.
-- ============================================================

create table public.lezioni (
    id uuid primary key default gen_random_uuid(),

    sezione_corso_id uuid not null
        references public.sezioni_corso(id) on delete restrict,

    data_lezione date not null,

    ora_inizio time not null,
    ora_fine time not null,

    stato text not null default 'PROGRAMMATA'
        check (stato in ('PROGRAMMATA', 'SVOLTA', 'ANNULLATA')),

    note text,

    data_creazione timestamptz not null default now(),
    data_modifica timestamptz not null default now(),

    constraint chk_lezione_orario
        check (ora_fine > ora_inizio),

    constraint uq_lezione_sezione_data
        unique (sezione_corso_id, data_lezione)
);

create index idx_lezioni_data
    on public.lezioni (data_lezione);

create index idx_lezioni_sezione
    on public.lezioni (sezione_corso_id);

create index idx_lezioni_stato
    on public.lezioni (stato);


-- ============================================================
-- PRESENZE
-- ============================================================

create table public.presenze (
    id uuid primary key default gen_random_uuid(),

    lezione_id uuid not null
        references public.lezioni(id) on delete cascade,

    atleta_id uuid not null
        references public.atleti(id) on delete restrict,

    stato text not null
        check (stato in ('PRESENTE', 'ASSENTE', 'GIUSTIFICATO')),

    ora_registrazione timestamptz not null default now(),

    note text,

    constraint uq_presenza_lezione_atleta
        unique (lezione_id, atleta_id)
);

create index idx_presenze_lezione
    on public.presenze (lezione_id);

create index idx_presenze_atleta
    on public.presenze (atleta_id);

create index idx_presenze_stato
    on public.presenze (stato);


-- ============================================================
-- RLS
-- Le policy dettagliate verranno definite successivamente,
-- dopo aver completato tutte le tabelle.
-- ============================================================

alter table public.corsi enable row level security;
alter table public.istruttori_corso enable row level security;
alter table public.sezioni_corso enable row level security;
alter table public.iscrizioni_corso enable row level security;
alter table public.iscrizioni_sezione enable row level security;
alter table public.lezioni enable row level security;
alter table public.presenze enable row level security;