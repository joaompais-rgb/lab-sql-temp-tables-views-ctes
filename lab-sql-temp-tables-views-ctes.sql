-- =====================================================================
-- Lab | Temporary Tables, Views and CTEs (base de datos sakila)
-- Informe resumen de clientes en tres pasos.
--
-- Diferencias clave:
--   VIEW (vista): consulta guardada con nombre. No guarda datos; cada vez que la uso
--       se vuelve a ejecutar, así que siempre está al día. Queda en la base de datos.
--   TEMPORARY TABLE: tabla real con los datos copiados en ese momento. Solo existe
--       en mi sesión y desaparece al cerrar la conexión.
--   CTE (WITH ...): consulta con nombre que solo existe dentro de la consulta que la usa.
-- =====================================================================
USE sakila;


-- ---------------------------------------------------------------------
-- Paso 1. Vista con el resumen de alquileres de cada cliente
-- ---------------------------------------------------------------------
-- LEFT JOIN desde customer para no perder a ningún cliente aunque no tuviera alquileres
-- (tendría rental_count = 0). COUNT(r.rental_id) cuenta solo los alquileres reales:
-- COUNT(columna) ignora los NULL, mientras que COUNT(*) contaría 1 en ese caso.
-- CREATE OR REPLACE permite volver a ejecutar el script sin error si la vista ya existe.
CREATE OR REPLACE VIEW customer_rental_summary AS
SELECT c.customer_id,
       CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
       c.email,
       COUNT(r.rental_id)                      AS rental_count
FROM customer AS c
LEFT JOIN rental AS r ON c.customer_id = r.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email;

-- Comprobación
SELECT * FROM customer_rental_summary LIMIT 10;


-- ---------------------------------------------------------------------
-- Paso 2. Tabla temporal con el total pagado por cada cliente
-- ---------------------------------------------------------------------
-- Como pide el enunciado, parto de la vista del Paso 1 y la uno con payment.
-- DROP ... IF EXISTS antes de crearla, para poder ejecutar el script varias veces.
-- Por qué una tabla temporal aquí: el total pagado exige recorrer los 16 000 pagos;
-- guardándolo una vez, las consultas siguientes lo leen ya calculado.
DROP TEMPORARY TABLE IF EXISTS customer_payment_summary;

CREATE TEMPORARY TABLE customer_payment_summary AS
SELECT crs.customer_id,
       ROUND(SUM(p.amount), 2) AS total_paid
FROM customer_rental_summary AS crs
JOIN payment AS p ON crs.customer_id = p.customer_id
GROUP BY crs.customer_id;

-- Comprobación
SELECT * FROM customer_payment_summary LIMIT 10;


-- ---------------------------------------------------------------------
-- Paso 3. CTE y el informe final
-- ---------------------------------------------------------------------
-- La CTE (customer_summary) une la vista y la tabla temporal por customer_id.
-- Después, la consulta principal calcula la columna derivada average_payment_per_rental.
-- NULLIF(rental_count, 0) evita un error de división entre cero si algún cliente
-- no tuviera alquileres: dividir entre NULL da NULL en lugar de fallar.
WITH customer_summary AS (
    SELECT crs.customer_name,
           crs.email,
           crs.rental_count,
           cps.total_paid
    FROM customer_rental_summary AS crs
    JOIN customer_payment_summary AS cps ON crs.customer_id = cps.customer_id
)
SELECT customer_name,
       email,
       rental_count,
       total_paid,
       ROUND(total_paid / NULLIF(rental_count, 0), 2) AS average_payment_per_rental
FROM customer_summary
ORDER BY total_paid DESC;
