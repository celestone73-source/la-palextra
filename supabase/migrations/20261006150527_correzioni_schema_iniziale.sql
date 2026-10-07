-- ============================================================
-- LA PALEXTRA
-- Correzioni schema iniziale
-- ============================================================


-- ============================================================
-- RUOLI INIZIALI
-- ============================================================

insert into public.ruoli (codice, nome, descrizione)
values
    ('PROPRIETARIO', 'Proprietario', 'Accesso completo al sistema'),
    ('AMMINISTRATORE', 'Amministratore', 'Gestione amministrativa della palestra'),
    ('ISTRUTTORE', 'Istruttore', 'Gestione dei corsi e delle presenze'),
    ('ATLETA', 'Atleta', 'Accesso ai propri dati e alle proprie attività')
on conflict (codice) do nothing;


-- ============================================================
-- PERMESSI INIZIALI
-- ============================================================

insert into public.permessi (codice, nome, descrizione)
values
    ('atleti.visualizza', 'Visualizza atleti', 'Visualizzazione degli atleti'),
    ('atleti.crea', 'Crea atleti', 'Creazione di nuovi atleti'),
    ('atleti.modifica', 'Modifica atleti', 'Modifica dei dati degli atleti'),
    ('atleti.elimina', 'Elimina atleti', 'Eliminazione degli atleti'),

    ('corsi.visualizza', 'Visualizza corsi', 'Visualizzazione dei corsi'),
    ('corsi.crea', 'Crea corsi', 'Creazione dei corsi'),
    ('corsi.modifica', 'Modifica corsi', 'Modifica dei corsi'),

    ('lezioni.visualizza', 'Visualizza lezioni', 'Visualizzazione delle lezioni'),
    ('lezioni.crea', 'Crea lezioni', 'Creazione delle lezioni'),
    ('lezioni.modifica', 'Modifica lezioni', 'Modifica delle lezioni'),

    ('presenze.visualizza', 'Visualizza presenze', 'Visualizzazione delle presenze'),
    ('presenze.registra', 'Registra presenze', 'Registrazione delle presenze'),

    ('certificati.visualizza', 'Visualizza certificati', 'Visualizzazione dei certificati'),
    ('certificati.carica', 'Carica certificati', 'Caricamento dei certificati'),

    ('abbonamenti.visualizza', 'Visualizza abbonamenti', 'Visualizzazione degli abbonamenti'),
    ('abbonamenti.gestisci', 'Gestisci abbonamenti', 'Gestione degli abbonamenti'),

    ('pagamenti.visualizza', 'Visualizza pagamenti', 'Visualizzazione dei pagamenti'),
    ('pagamenti.gestisci', 'Gestisci pagamenti', 'Gestione dei pagamenti')
on conflict (codice) do nothing;


-- ============================================================
-- INDICI AGGIUNTIVI
-- ============================================================

create index if not exists idx_ruoli_utenti_ruolo
    on public.ruoli_utenti (ruolo_id);

create index if not exists idx_permessi_ruoli_permesso
    on public.permessi_ruoli (permesso_id);

create index if not exists idx_istruttori_corso_corso
    on public.istruttori_corso (corso_id);


-- ============================================================
-- EVITA DUPLICAZIONI DI SEZIONI IDENTICHE
-- ============================================================

create unique index if not exists uq_sezione_corso_orario
    on public.sezioni_corso (
        corso_id,
        giorno_settimana,
        ora_inizio,
        ora_fine
    );


-- ============================================================
-- FUNZIONE PER AGGIORNARE data_modifica
-- ============================================================

create or replace function public.aggiorna_data_modifica()
returns trigger
language plpgsql
as $$
begin
    new.data_modifica = now();
    return new;
end;
$$;


-- ============================================================
-- TRIGGER data_modifica
-- ============================================================

drop trigger if exists trg_profili_data_modifica
    on public.profili;

create trigger trg_profili_data_modifica
before update on public.profili
for each row
execute function public.aggiorna_data_modifica();


drop trigger if exists trg_atleti_data_modifica
    on public.atleti;

create trigger trg_atleti_data_modifica
before update on public.atleti
for each row
execute function public.aggiorna_data_modifica();


drop trigger if exists trg_tessere_msp_data_modifica
    on public.tessere_msp;

create trigger trg_tessere_msp_data_modifica
before update on public.tessere_msp
for each row
execute function public.aggiorna_data_modifica();


drop trigger if exists trg_assicurazioni_data_modifica
    on public.assicurazioni;

create trigger trg_assicurazioni_data_modifica
before update on public.assicurazioni
for each row
execute function public.aggiorna_data_modifica();


drop trigger if exists trg_corsi_data_modifica
    on public.corsi;

create trigger trg_corsi_data_modifica
before update on public.corsi
for each row
execute function public.aggiorna_data_modifica();


drop trigger if exists trg_sezioni_corso_data_modifica
    on public.sezioni_corso;

create trigger trg_sezioni_corso_data_modifica
before update on public.sezioni_corso
for each row
execute function public.aggiorna_data_modifica();


drop trigger if exists trg_iscrizioni_corso_data_modifica
    on public.iscrizioni_corso;

create trigger trg_iscrizioni_corso_data_modifica
before update on public.iscrizioni_corso
for each row
execute function public.aggiorna_data_modifica();


drop trigger if exists trg_lezioni_data_modifica
    on public.lezioni;

create trigger trg_lezioni_data_modifica
before update on public.lezioni
for each row
execute function public.aggiorna_data_modifica();


drop trigger if exists trg_abbonamenti_data_modifica
    on public.abbonamenti;

create trigger trg_abbonamenti_data_modifica
before update on public.abbonamenti
for each row
execute function public.aggiorna_data_modifica();


drop trigger if exists trg_rate_abbonamento_data_modifica
    on public.rate_abbonamento;

create trigger trg_rate_abbonamento_data_modifica
before update on public.rate_abbonamento
for each row
execute function public.aggiorna_data_modifica();


drop trigger if exists trg_quote_iscrizione_data_modifica
    on public.quote_iscrizione;

create trigger trg_quote_iscrizione_data_modifica
before update on public.quote_iscrizione
for each row
execute function public.aggiorna_data_modifica();


drop trigger if exists trg_regole_sconto_data_modifica
    on public.regole_sconto;

create trigger trg_regole_sconto_data_modifica
before update on public.regole_sconto
for each row
execute function public.aggiorna_data_modifica();


drop trigger if exists trg_dispositivi_push_data_modifica
    on public.dispositivi_push;

create trigger trg_dispositivi_push_data_modifica
before update on public.dispositivi_push
for each row
execute function public.aggiorna_data_modifica();


drop trigger if exists trg_impostazioni_palestra_data_modifica
    on public.impostazioni_palestra;

create trigger trg_impostazioni_palestra_data_modifica
before update on public.impostazioni_palestra
for each row
execute function public.aggiorna_data_modifica();


-- ============================================================
-- VINCOLO: IMPORTO FINALE DELL'ABBONAMENTO
-- ============================================================

alter table public.abbonamenti
drop constraint if exists chk_abbonamenti_importo;

alter table public.abbonamenti
add constraint chk_abbonamenti_importo
check (importo_finale <= importo_base);


-- ============================================================
-- VINCOLO: SCONTO RATA
-- ============================================================

alter table public.rate_abbonamento
drop constraint if exists chk_rata_sconto;

alter table public.rate_abbonamento
add constraint chk_rata_sconto
check (sconto <= importo_base);


-- ============================================================
-- RLS: nessuna policy applicativa ancora.
--
-- La RLS è già abilitata sulle tabelle.
-- Le policy definitive saranno create nella migration
-- dedicata alla sicurezza.
-- ============================================================