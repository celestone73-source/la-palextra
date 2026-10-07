-- ============================================================
-- LA PALEXTRA
-- Migration: sicurezza RLS
-- ============================================================


-- ============================================================
-- FUNZIONI DI SUPPORTO
-- ============================================================

-- ------------------------------------------------------------
-- Verifica se l'utente autenticato è PROPRIETARIO
-- ------------------------------------------------------------

create or replace function public.utente_e_proprietario()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.ruoli_utenti ru
        join public.ruoli r
            on r.id = ru.ruolo_id
        where ru.utente_id = (select auth.uid())
          and r.codice = 'PROPRIETARIO'
    );
$$;


-- ------------------------------------------------------------
-- Verifica se l'utente autenticato possiede un permesso
-- ------------------------------------------------------------

create or replace function public.utente_ha_permesso(
    p_permesso text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select
        public.utente_e_proprietario()
        or exists (
            select 1
            from public.ruoli_utenti ru
            join public.permessi_ruoli pr
                on pr.ruolo_id = ru.ruolo_id
            join public.permessi p
                on p.id = pr.permesso_id
            where ru.utente_id = (select auth.uid())
              and p.codice = p_permesso
        );
$$;


-- ------------------------------------------------------------
-- Verifica se l'utente è AMMINISTRATORE
-- ------------------------------------------------------------

create or replace function public.utente_e_amministratore()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.ruoli_utenti ru
        join public.ruoli r
            on r.id = ru.ruolo_id
        where ru.utente_id = (select auth.uid())
          and r.codice = 'AMMINISTRATORE'
    );
$$;


-- ------------------------------------------------------------
-- Verifica se l'utente è ISTRUTTORE di un determinato corso
-- ------------------------------------------------------------

create or replace function public.utente_e_istruttore_corso(
    p_corso_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.istruttori_corso ic
        where ic.corso_id = p_corso_id
          and ic.istruttore_id = (select auth.uid())
    );
$$;


-- ------------------------------------------------------------
-- Verifica se l'utente autenticato è iscritto a un corso
-- ------------------------------------------------------------

create or replace function public.utente_iscritto_corso(
    p_corso_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.iscrizioni_corso ic
        where ic.corso_id = p_corso_id
          and ic.atleta_id = (select auth.uid())
          and ic.stato in ('ATTIVA', 'SOSPESA')
          and current_date between ic.data_inizio and ic.data_fine
    );
$$;


-- ------------------------------------------------------------
-- Verifica se un atleta appartiene a un corso assegnato
-- all'istruttore autenticato
-- ------------------------------------------------------------

create or replace function public.istruttore_vede_atleta(
    p_atleta_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.istruttori_corso ic
        join public.iscrizioni_corso iscr
            on iscr.corso_id = ic.corso_id
        where ic.istruttore_id = (select auth.uid())
          and iscr.atleta_id = p_atleta_id
          and iscr.stato in ('ATTIVA', 'SOSPESA')
          and current_date between iscr.data_inizio and iscr.data_fine
    );
$$;


-- ------------------------------------------------------------
-- Verifica se una lezione appartiene a un corso
-- dell'istruttore autenticato
-- ------------------------------------------------------------

create or replace function public.istruttore_vede_lezione(
    p_lezione_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.lezioni l
        join public.sezioni_corso sc
            on sc.id = l.sezione_corso_id
        join public.istruttori_corso ic
            on ic.corso_id = sc.corso_id
        where l.id = p_lezione_id
          and ic.istruttore_id = (select auth.uid())
    );
$$;


-- ============================================================
-- ASSOCIAZIONE PERMESSI AI RUOLI
-- ============================================================

-- ------------------------------------------------------------
-- AMMINISTRATORE
-- Tutti i permessi amministrativi definiti finora.
-- ------------------------------------------------------------

insert into public.permessi_ruoli (ruolo_id, permesso_id)
select r.id, p.id
from public.ruoli r
cross join public.permessi p
where r.codice = 'AMMINISTRATORE'
on conflict do nothing;


-- ------------------------------------------------------------
-- ISTRUTTORE
-- ------------------------------------------------------------

insert into public.permessi_ruoli (ruolo_id, permesso_id)
select r.id, p.id
from public.ruoli r
join public.permessi p
    on p.codice in (
        'atleti.visualizza',
        'corsi.visualizza',
        'lezioni.visualizza',
        'lezioni.modifica',
        'presenze.visualizza',
        'presenze.registra'
    )
where r.codice = 'ISTRUTTORE'
on conflict do nothing;


-- ------------------------------------------------------------
-- ATLETA
-- ------------------------------------------------------------

insert into public.permessi_ruoli (ruolo_id, permesso_id)
select r.id, p.id
from public.ruoli r
join public.permessi p
    on p.codice in (
        'corsi.visualizza',
        'lezioni.visualizza',
        'presenze.visualizza',
        'certificati.visualizza',
        'certificati.carica',
        'abbonamenti.visualizza',
        'pagamenti.visualizza'
    )
where r.codice = 'ATLETA'
on conflict do nothing;


-- ============================================================
-- PROFILI
-- ============================================================

alter table public.profili force row level security;


create policy profili_visualizza
on public.profili
for select
to authenticated
using (
    id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.visualizza')
);


create policy profili_inserisci
on public.profili
for insert
to authenticated
with check (
    id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.crea')
);


create policy profili_modifica
on public.profili
for update
to authenticated
using (
    id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.modifica')
)
with check (
    id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.modifica')
);


-- ============================================================
-- ATLETI
-- ============================================================

alter table public.atleti force row level security;


create policy atleti_visualizza
on public.atleti
for select
to authenticated
using (
    profilo_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.visualizza')
    or public.istruttore_vede_atleta(profilo_id)
);


create policy atleti_inserisci
on public.atleti
for insert
to authenticated
with check (
    profilo_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.crea')
);


create policy atleti_modifica
on public.atleti
for update
to authenticated
using (
    profilo_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.modifica')
)
with check (
    profilo_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.modifica')
);


create policy atleti_elimina
on public.atleti
for delete
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.elimina')
);


-- ============================================================
-- RUOLI
-- ============================================================

alter table public.ruoli force row level security;


create policy ruoli_visualizza
on public.ruoli
for select
to authenticated
using (
    public.utente_e_proprietario()
);


-- ============================================================
-- PERMESSI
-- ============================================================

alter table public.permessi force row level security;


create policy permessi_visualizza
on public.permessi
for select
to authenticated
using (
    public.utente_e_proprietario()
);


-- ============================================================
-- RUOLI UTENTI
-- ============================================================

alter table public.ruoli_utenti force row level security;


create policy ruoli_utenti_visualizza
on public.ruoli_utenti
for select
to authenticated
using (
    utente_id = (select auth.uid())
    or public.utente_e_proprietario()
);


create policy ruoli_utenti_gestisci
on public.ruoli_utenti
for all
to authenticated
using (
    public.utente_e_proprietario()
)
with check (
    public.utente_e_proprietario()
);


-- ============================================================
-- PERMESSI RUOLI
-- ============================================================

alter table public.permessi_ruoli force row level security;


create policy permessi_ruoli_visualizza
on public.permessi_ruoli
for select
to authenticated
using (
    public.utente_e_proprietario()
);


create policy permessi_ruoli_gestisci
on public.permessi_ruoli
for all
to authenticated
using (
    public.utente_e_proprietario()
)
with check (
    public.utente_e_proprietario()
);


-- ============================================================
-- CORSI
-- ============================================================

alter table public.corsi force row level security;


create policy corsi_visualizza
on public.corsi
for select
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('corsi.visualizza')
);


create policy corsi_inserisci
on public.corsi
for insert
to authenticated
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('corsi.crea')
);


create policy corsi_modifica
on public.corsi
for update
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('corsi.modifica')
)
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('corsi.modifica')
);


-- ============================================================
-- ISTRUTTORI CORSO
-- ============================================================

alter table public.istruttori_corso force row level security;


create policy istruttori_corso_visualizza
on public.istruttori_corso
for select
to authenticated
using (
    istruttore_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('corsi.visualizza')
);


create policy istruttori_corso_gestisci
on public.istruttori_corso
for all
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('corsi.modifica')
)
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('corsi.modifica')
);


-- ============================================================
-- SEZIONI CORSO
-- ============================================================

alter table public.sezioni_corso force row level security;


create policy sezioni_corso_visualizza
on public.sezioni_corso
for select
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('corsi.visualizza')
    or public.utente_iscritto_corso(corso_id)
    or public.utente_e_istruttore_corso(corso_id)
);


create policy sezioni_corso_gestisci
on public.sezioni_corso
for all
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('corsi.modifica')
)
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('corsi.modifica')
);


-- ============================================================
-- ISCRIZIONI CORSO
-- ============================================================

alter table public.iscrizioni_corso force row level security;


create policy iscrizioni_corso_visualizza
on public.iscrizioni_corso
for select
to authenticated
using (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.visualizza')
    or public.istruttore_vede_atleta(atleta_id)
);


create policy iscrizioni_corso_gestisci
on public.iscrizioni_corso
for all
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.modifica')
)
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.modifica')
);


-- ============================================================
-- ISCRIZIONI SEZIONE
-- ============================================================

alter table public.iscrizioni_sezione force row level security;


create policy iscrizioni_sezione_visualizza
on public.iscrizioni_sezione
for select
to authenticated
using (
    exists (
        select 1
        from public.iscrizioni_corso ic
        where ic.id = iscrizione_corso_id
          and (
              ic.atleta_id = (select auth.uid())
              or public.utente_e_proprietario()
              or public.utente_ha_permesso('atleti.visualizza')
              or public.istruttore_vede_atleta(ic.atleta_id)
          )
    )
);


create policy iscrizioni_sezione_gestisci
on public.iscrizioni_sezione
for all
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.modifica')
)
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.modifica')
);


-- ============================================================
-- LEZIONI
-- ============================================================

alter table public.lezioni force row level security;


create policy lezioni_visualizza
on public.lezioni
for select
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('lezioni.visualizza')
    or exists (
        select 1
        from public.sezioni_corso sc
        where sc.id = sezione_corso_id
          and public.utente_iscritto_corso(sc.corso_id)
    )
    or public.istruttore_vede_lezione(id)
);


create policy lezioni_inserisci
on public.lezioni
for insert
to authenticated
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('lezioni.crea')
);


create policy lezioni_modifica
on public.lezioni
for update
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('lezioni.modifica')
    or public.istruttore_vede_lezione(id)
)
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('lezioni.modifica')
    or public.istruttore_vede_lezione(id)
);


-- ============================================================
-- PRESENZE
-- ============================================================

alter table public.presenze force row level security;


create policy presenze_visualizza
on public.presenze
for select
to authenticated
using (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('presenze.visualizza')
    or public.istruttore_vede_lezione(lezione_id)
);


create policy presenze_inserisci
on public.presenze
for insert
to authenticated
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('presenze.registra')
    or public.istruttore_vede_lezione(lezione_id)
);


create policy presenze_modifica
on public.presenze
for update
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('presenze.registra')
    or public.istruttore_vede_lezione(lezione_id)
)
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('presenze.registra')
    or public.istruttore_vede_lezione(lezione_id)
);


-- ============================================================
-- CERTIFICATI MEDICI
-- ============================================================

alter table public.certificati_medici force row level security;


create policy certificati_visualizza
on public.certificati_medici
for select
to authenticated
using (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('certificati.visualizza')
);


create policy certificati_inserisci
on public.certificati_medici
for insert
to authenticated
with check (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('certificati.carica')
);


create policy certificati_modifica
on public.certificati_medici
for update
to authenticated
using (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
)
with check (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
);


-- ============================================================
-- TESSERE MSP
-- ============================================================

alter table public.tessere_msp force row level security;


create policy tessere_msp_visualizza
on public.tessere_msp
for select
to authenticated
using (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.visualizza')
);


create policy tessere_msp_gestisci
on public.tessere_msp
for all
to authenticated
using (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.modifica')
)
with check (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.modifica')
);


-- ============================================================
-- ASSICURAZIONI
-- ============================================================

alter table public.assicurazioni force row level security;


create policy assicurazioni_visualizza
on public.assicurazioni
for select
to authenticated
using (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.visualizza')
);


create policy assicurazioni_gestisci
on public.assicurazioni
for all
to authenticated
using (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.modifica')
)
with check (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('atleti.modifica')
);


-- ============================================================
-- ABBONAMENTI
-- ============================================================

alter table public.abbonamenti force row level security;


create policy abbonamenti_visualizza
on public.abbonamenti
for select
to authenticated
using (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.visualizza')
);


create policy abbonamenti_gestisci
on public.abbonamenti
for all
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.gestisci')
)
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.gestisci')
);


-- ============================================================
-- ABBONAMENTI CORSI
-- ============================================================

alter table public.abbonamenti_corsi force row level security;


create policy abbonamenti_corsi_visualizza
on public.abbonamenti_corsi
for select
to authenticated
using (
    exists (
        select 1
        from public.abbonamenti a
        where a.id = abbonamento_id
          and (
              a.atleta_id = (select auth.uid())
              or public.utente_e_proprietario()
              or public.utente_ha_permesso('abbonamenti.visualizza')
          )
    )
);


create policy abbonamenti_corsi_gestisci
on public.abbonamenti_corsi
for all
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.gestisci')
)
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.gestisci')
);


-- ============================================================
-- RATE ABBONAMENTO
-- ============================================================

alter table public.rate_abbonamento force row level security;


create policy rate_abbonamento_visualizza
on public.rate_abbonamento
for select
to authenticated
using (
    exists (
        select 1
        from public.abbonamenti a
        where a.id = abbonamento_id
          and (
              a.atleta_id = (select auth.uid())
              or public.utente_e_proprietario()
              or public.utente_ha_permesso('abbonamenti.visualizza')
          )
    )
);


create policy rate_abbonamento_gestisci
on public.rate_abbonamento
for all
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.gestisci')
)
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.gestisci')
);


-- ============================================================
-- QUOTE ISCRIZIONE
-- ============================================================

alter table public.quote_iscrizione force row level security;


create policy quote_iscrizione_visualizza
on public.quote_iscrizione
for select
to authenticated
using (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.visualizza')
);


create policy quote_iscrizione_gestisci
on public.quote_iscrizione
for all
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.gestisci')
)
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.gestisci')
);


-- ============================================================
-- PAGAMENTI
-- ============================================================

alter table public.pagamenti force row level security;


create policy pagamenti_visualizza
on public.pagamenti
for select
to authenticated
using (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('pagamenti.visualizza')
);


create policy pagamenti_gestisci
on public.pagamenti
for all
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('pagamenti.gestisci')
)
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('pagamenti.gestisci')
);


-- ============================================================
-- REGOLE SCONTO
-- ============================================================

alter table public.regole_sconto force row level security;


create policy regole_sconto_visualizza
on public.regole_sconto
for select
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.gestisci')
);


create policy regole_sconto_gestisci
on public.regole_sconto
for all
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.gestisci')
)
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.gestisci')
);


-- ============================================================
-- SCONTI APPLICATI
-- ============================================================

alter table public.sconti_applicati force row level security;


create policy sconti_applicati_visualizza
on public.sconti_applicati
for select
to authenticated
using (
    atleta_id = (select auth.uid())
    or public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.visualizza')
);


create policy sconti_applicati_gestisci
on public.sconti_applicati
for all
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.gestisci')
)
with check (
    public.utente_e_proprietario()
    or public.utente_ha_permesso('abbonamenti.gestisci')
);


-- ============================================================
-- NOTIFICHE
-- ============================================================

alter table public.notifiche force row level security;


create policy notifiche_visualizza
on public.notifiche
for select
to authenticated
using (
    utente_id = (select auth.uid())
    or public.utente_e_proprietario()
);


-- ============================================================
-- DISPOSITIVI PUSH
-- ============================================================

alter table public.dispositivi_push force row level security;


create policy dispositivi_push_gestisci
on public.dispositivi_push
for all
to authenticated
using (
    utente_id = (select auth.uid())
    or public.utente_e_proprietario()
)
with check (
    utente_id = (select auth.uid())
    or public.utente_e_proprietario()
);


-- ============================================================
-- REGISTRO ACCESSI
-- Solo il proprietario può leggere/modificare l'audit.
-- ============================================================

alter table public.registri_accesso force row level security;


create policy registri_accesso_visualizza
on public.registri_accesso
for select
to authenticated
using (
    public.utente_e_proprietario()
);


-- ============================================================
-- IMPOSTAZIONI PALESTRA
-- ============================================================

alter table public.impostazioni_palestra force row level security;


create policy impostazioni_palestra_visualizza
on public.impostazioni_palestra
for select
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_e_amministratore()
);


create policy impostazioni_palestra_gestisci
on public.impostazioni_palestra
for all
to authenticated
using (
    public.utente_e_proprietario()
    or public.utente_e_amministratore()
)
with check (
    public.utente_e_proprietario()
    or public.utente_e_amministratore()
);