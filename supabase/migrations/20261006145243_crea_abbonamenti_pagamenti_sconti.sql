-- ============================================================
-- LA PALEXTRA
-- Migration: abbonamenti, pagamenti e sconti
-- ============================================================


-- ============================================================
-- ABBONAMENTI
-- ============================================================

create table public.abbonamenti (
    id uuid primary key default gen_random_uuid(),

    atleta_id uuid not null
        references public.atleti(id) on delete restrict,

    data_inizio date not null,
    data_fine date not null,

    stato text not null default 'ATTIVO'
        check (stato in ('ATTIVO', 'SOSPESO', 'TERMINATO')),

    importo_base numeric(10,2) not null
        check (importo_base >= 0),

    importo_finale numeric(10,2) not null
        check (importo_finale >= 0),

    note text,

    data_creazione timestamptz not null default now(),
    data_modifica timestamptz not null default now(),

    constraint chk_abbonamenti_date
        check (data_fine >= data_inizio),

    constraint chk_abbonamenti_importo
        check (importo_finale <= importo_base)
);

create index idx_abbonamenti_atleta
    on public.abbonamenti (atleta_id);

create index idx_abbonamenti_periodo
    on public.abbonamenti (data_inizio, data_fine);

create index idx_abbonamenti_stato
    on public.abbonamenti (stato);


-- ============================================================
-- ABBONAMENTI CORSI
-- ============================================================

create table public.abbonamenti_corsi (
    abbonamento_id uuid not null
        references public.abbonamenti(id) on delete cascade,

    corso_id uuid not null
        references public.corsi(id) on delete restrict,

    data_creazione timestamptz not null default now(),

    primary key (abbonamento_id, corso_id)
);

create index idx_abbonamenti_corsi_corso
    on public.abbonamenti_corsi (corso_id);


-- ============================================================
-- RATE ABBONAMENTO
-- ============================================================

create table public.rate_abbonamento (
    id uuid primary key default gen_random_uuid(),

    abbonamento_id uuid not null
        references public.abbonamenti(id) on delete restrict,

    anno integer not null,
    mese smallint not null
        check (mese between 1 and 12),

    importo_base numeric(10,2) not null
        check (importo_base >= 0),

    sconto numeric(10,2) not null default 0
        check (sconto >= 0),

    importo_finale numeric(10,2) not null
        check (importo_finale >= 0),

    data_scadenza date not null,

    stato text not null default 'DA_PAGARE'
        check (stato in (
            'DA_PAGARE',
            'PAGATA',
            'SCADUTA',
            'ANNULLATA'
        )),

    data_pagamento date,

    note text,

    data_creazione timestamptz not null default now(),
    data_modifica timestamptz not null default now(),

    constraint uq_rata_abbonamento_periodo
        unique (abbonamento_id, anno, mese),

    constraint chk_rata_sconto
        check (sconto <= importo_base),

    constraint chk_rata_importo
        check (importo_finale = importo_base - sconto),

    constraint chk_rata_data_pagamento
        check (
            (stato = 'PAGATA' and data_pagamento is not null)
            or
            (stato <> 'PAGATA')
        )
);

create index idx_rate_abbonamento_abbonamento
    on public.rate_abbonamento (abbonamento_id);

create index idx_rate_abbonamento_scadenza
    on public.rate_abbonamento (data_scadenza);

create index idx_rate_abbonamento_stato
    on public.rate_abbonamento (stato);


-- ============================================================
-- QUOTE ISCRIZIONE
-- ============================================================

create table public.quote_iscrizione (
    id uuid primary key default gen_random_uuid(),

    atleta_id uuid not null
        references public.atleti(id) on delete restrict,

    anno integer not null,

    importo numeric(10,2) not null
        check (importo >= 0),

    data_scadenza date not null,

    stato text not null default 'DA_PAGARE'
        check (stato in (
            'DA_PAGARE',
            'PAGATA',
            'SCADUTA',
            'ANNULLATA'
        )),

    data_pagamento date,

    note text,

    data_creazione timestamptz not null default now(),
    data_modifica timestamptz not null default now(),

    constraint uq_quote_iscrizione_atleta_anno
        unique (atleta_id, anno),

    constraint chk_quota_data_pagamento
        check (
            (stato = 'PAGATA' and data_pagamento is not null)
            or
            (stato <> 'PAGATA')
        )
);

create index idx_quote_iscrizione_atleta
    on public.quote_iscrizione (atleta_id);

create index idx_quote_iscrizione_scadenza
    on public.quote_iscrizione (data_scadenza);

create index idx_quote_iscrizione_stato
    on public.quote_iscrizione (stato);


-- ============================================================
-- PAGAMENTI
--
-- Un pagamento può essere associato:
--   - a una rata di abbonamento
--   - oppure a una quota di iscrizione
--
-- Non può essere associato contemporaneamente a entrambe.
-- ============================================================

create table public.pagamenti (
    id uuid primary key default gen_random_uuid(),

    atleta_id uuid not null
        references public.atleti(id) on delete restrict,

    rata_abbonamento_id uuid
        references public.rate_abbonamento(id) on delete restrict,

    quota_iscrizione_id uuid
        references public.quote_iscrizione(id) on delete restrict,

    importo numeric(10,2) not null
        check (importo > 0),

    data_pagamento date not null,

    metodo_pagamento text not null
        check (metodo_pagamento in (
            'CONTANTI',
            'POS',
            'BONIFICO',
            'ALTRO'
        )),

    note text,

    data_creazione timestamptz not null default now(),

    constraint chk_pagamento_destinazione
        check (
            (rata_abbonamento_id is not null
             and quota_iscrizione_id is null)
            or
            (rata_abbonamento_id is null
             and quota_iscrizione_id is not null)
        )
);

create index idx_pagamenti_atleta
    on public.pagamenti (atleta_id);

create index idx_pagamenti_rata
    on public.pagamenti (rata_abbonamento_id);

create index idx_pagamenti_quota
    on public.pagamenti (quota_iscrizione_id);

create index idx_pagamenti_data
    on public.pagamenti (data_pagamento);


-- ============================================================
-- REGOLE SCONTO
-- ============================================================

create table public.regole_sconto (
    id uuid primary key default gen_random_uuid(),

    nome text not null,
    descrizione text,

    tipo text not null
        check (tipo in (
            'PERCENTUALE',
            'IMPORTO',
            'TARIFFA_FISSA'
        )),

    valore numeric(10,2) not null
        check (valore >= 0),

    data_inizio date not null,
    data_fine date,

    attiva boolean not null default true,

    priorita integer not null default 0,

    data_creazione timestamptz not null default now(),
    data_modifica timestamptz not null default now(),

    constraint chk_regole_sconto_date
        check (
            data_fine is null
            or data_fine >= data_inizio
        )
);

create index idx_regole_sconto_attiva
    on public.regole_sconto (attiva);

create index idx_regole_sconto_periodo
    on public.regole_sconto (data_inizio, data_fine);


-- ============================================================
-- SCONTI APPLICATI
--
-- Questo è lo storico dello sconto realmente applicato.
-- La modifica futura di una regola non modifica questo record.
-- ============================================================

create table public.sconti_applicati (
    id uuid primary key default gen_random_uuid(),

    atleta_id uuid not null
        references public.atleti(id) on delete restrict,

    rata_abbonamento_id uuid not null
        references public.rate_abbonamento(id) on delete restrict,

    regola_sconto_id uuid
        references public.regole_sconto(id) on delete restrict,

    descrizione text,

    importo_sconto numeric(10,2) not null
        check (importo_sconto >= 0),

    percentuale_sconto numeric(5,2)
        check (
            percentuale_sconto is null
            or (
                percentuale_sconto >= 0
                and percentuale_sconto <= 100
            )
        ),

    data_creazione timestamptz not null default now()
);

create index idx_sconti_applicati_atleta
    on public.sconti_applicati (atleta_id);

create index idx_sconti_applicati_rata
    on public.sconti_applicati (rata_abbonamento_id);

create index idx_sconti_applicati_regola
    on public.sconti_applicati (regola_sconto_id);


-- ============================================================
-- RLS
-- ============================================================

alter table public.abbonamenti enable row level security;
alter table public.abbonamenti_corsi enable row level security;
alter table public.rate_abbonamento enable row level security;
alter table public.quote_iscrizione enable row level security;
alter table public.pagamenti enable row level security;
alter table public.regole_sconto enable row level security;
alter table public.sconti_applicati enable row level security;