-- 1. Crear mediante instrucciones SQL las entidades de acuerdo con el modelo relacional definido.

CREATE DATABASE IF NOT EXISTS EJERCICIO;
USE EJERCICIO;

CREATE TABLE departamento(
codDepto VARCHAR(4),
nombreDpto VARCHAR(20) NOT NULL,
Ciudad VARCHAR(15),
codDirector VARCHAR(12),
PRIMARY KEY (codDepto)
);
DESCRIBE departamento;

CREATE TABLE empleado(
nDIEmp VARCHAR(12) NOT NULL,
nomEmp VARCHAR(30) NOT NULL,
sexEmp CHAR(1) NOT NULL,
fecNac DATE NOT NULL,
fecIncorporacion DATE NOT NULL,
salEmp FLOAT NOT NULL,
comisionE FLOAT NOT NULL,
cargoE VARCHAR(15) NOT NULL,
jefeID VARCHAR(12),
codDepto VARCHAR(4) NOT NULL,
PRIMARY KEY (nDIEmp),
FOREIGN KEY (codDepto) REFERENCES DEPARTAMENTO (codDepto),
FOREIGN KEY (jefeID) REFERENCES EMPLEADO (nDIEmp)
);
DESCRIBE empleado;


-- 2. Insertar datos en cada una de las tablas, al menos 40 empleados y 10 departamentos.

INSERT INTO departamento (codDepto, nombreDpto, Ciudad, codDirector) VALUES
('1000', 'DIRECCION',        'MADRID',   '00.000.001'),
('2000', 'INVESTIGACIÓN',    'MADRID',   '31.840.269'),
('3000', 'VENTAS',           'BARCELONA','12.345.678'),
('4000', 'MANTENIMIENTO',    'VALENCIA', '23.456.789'),
('5000', 'RECURSOS HUMANOS', 'MADRID',   '34.567.890'),
('6000', 'FINANZAS',         'SEVILLA',  '45.678.901'),
('7000', 'LOGISTICA',        'BILBAO',   '56.789.012'),
('8000', 'MARKETING',        'ZARAGOZA', '67.890.123'),
('9000', 'SISTEMAS',         'MADRID',   '78.901.234'),
('9100', 'CALIDAD',          'MALAGA',   '89.012.345');

INSERT INTO empleado (
    nDIEmp,          nomEmp,                      sexEmp, fecNac,fecIncorporacion, salEmp, comisionE,cargoE,         jefeID,     codDepto
) VALUES

--  DIRECCIÓN (1000)
('00.000.001', 'Ana María López García',          'F', '1970-01-15', '2000-02-01', 90000,     0, 'DIR. GENERAL',      NULL,        '1000'),

--  INVESTIGACIÓN (2000)
('31.840.269', 'Luis Alberto Ruiz Martínez',      'M', '1975-05-10', '2001-03-01', 80000,  5000, 'JEFE INVESTIG.',    NULL,        '2000'),
('20.000.001', 'Carlos Gómez Hernández',          'M', '1980-02-11', '2007-05-30', 45000,     0, 'INVESTIGADOR',      '31.840.269','2000'),
('20.000.002', 'María Torres Delgado',            'F', '1983-08-19', '2008-09-10', 47000,     0, 'INVESTIGADORA',     '31.840.269','2000'),
('20.000.003', 'Javier Ortega Sánchez',           'M', '1988-12-25', '2012-01-05', 26000,     0, 'INVESTIGADOR',      '31.840.269','2000'),
('20.000.004', 'Rubén Morales Padilla',           'M', '1995-03-03', '2020-02-01', 18000,     0, 'INVESTIGADOR',      '31.840.269','2000'),
('20.000.005', 'Laura Ramos Castillo',            'F', '1979-07-07', '2006-11-11', 52000,     0, 'INVESTIGADORA',     '31.840.269','2000'),
('20.000.006', 'Francisco Paredes Vera',          'M', '1984-06-10', '2010-03-15', 48000,     0, 'INVESTIGADOR',      '31.840.269','2000'),
('20.000.007', 'Claudia Medina Rojas',            'F', '1986-09-22', '2011-11-20', 50000,     0, 'INVESTIGADORA',     '31.840.269','2000'),

--  VENTAS (3000)
('12.345.678', 'Marta Jiménez Navarro',           'F', '1978-07-20', '2002-04-15', 85000, 15000, 'JEFE VENTAS',       NULL,        '3000'),
('10.000.001', 'Manuel Serrano Rubio',            'M', '1985-03-12', '2010-05-01', 30000,  5000, 'VENDEDOR',          '12.345.678','3000'),
('10.000.002', 'Lucía Díaz Márquez',              'F', '1987-07-08', '2011-09-15', 28000, 12000, 'VENDEDORA',         '12.345.678','3000'),
('10.000.003', 'Pedro Castillo Palma',            'M', '1990-01-20', '2015-03-10', 10000, 15000, 'VENDEDOR',          '12.345.678','3000'),
('10.000.004', 'María Flores Gutiérrez',          'F', '1992-11-02', '2016-06-01',  6000, 20000, 'VENDEDORA',         '12.345.678','3000'),
('10.000.005', 'David Iglesias Román',            'M', '1989-09-14', '2013-02-18',  9000, 15000, 'VENDEDOR',          '12.345.678','3000'),
('10.000.006', 'Silvia Vázquez Cortés',           'F', '1991-04-03', '2014-08-25', 32000,  8000, 'VENDEDORA',         '12.345.678','3000'),
('10.000.007', 'Alberto Herrera Jurado',          'M', '1984-06-22', '2009-01-12', 35000,  6000, 'VENDEDOR',          '12.345.678','3000'),
('10.000.008', 'Cristina León Santos',            'F', '1986-10-05', '2012-10-01', 27000,     0, 'VENDEDORA',         '12.345.678','3000'),
('10.000.009', 'Jorge Santana Valero',            'M', '1988-02-10', '2014-01-15', 33000,  7000, 'VENDEDOR',          '12.345.678','3000'),
('10.000.010', 'Patricia Núñez Gallego',          'F', '1993-05-18', '2018-09-10', 29000,  9000, 'VENDEDORA',         '12.345.678','3000'),

--  MANTENIMIENTO (4000)
('23.456.789', 'Carlos Muñoz Carreño',           'M', '1968-11-30', '1998-09-01', 75000,     0, 'JEFE MANTTO',       NULL,        '4000'),
('40.000.001', 'Samuel Soria Benítez',           'M', '1977-01-09', '2005-04-01', 30000,     0, 'TEC. MANTTO',       '23.456.789','4000'),
('40.000.002', 'Elena Barrios Pozo',             'F', '1982-03-17', '2009-07-21', 31000,     0, 'TEC. MANTTO',       '23.456.789','4000'),
('40.000.003', 'Miguel Angulo Prieto',           'M', '1984-11-29', '2010-09-14', 25000,     0, 'OPERARIO',          '23.456.789','4000'),
('40.000.004', 'Laura Cabello Navas',            'F', '1989-05-16', '2014-03-03', 24000,     0, 'OPERARIO',          '23.456.789','4000'),
('40.000.005', 'Héctor Reina Godoy',             'M', '1981-04-07', '2008-01-15', 32000,     0, 'OPERARIO',          '23.456.789','4000'),

--  RRHH (5000)
('34.567.890', 'Elena Rivas Cabrera',            'F', '1980-09-05', '2005-01-10', 70000,     0, 'JEFE RRHH',         NULL,        '5000'),
('50.000.001', 'Roberto Lozano Plaza',           'M', '1981-06-06', '2008-10-10', 33000,     0, 'TEC. RRHH',         '34.567.890','5000'),
('50.000.002', 'Alicia Montoro Salas',           'F', '1987-09-09', '2013-05-15', 25000,     0, 'SECRETARIA',        '34.567.890','5000'),
('50.000.003', 'Diego Ramírez Dueñas',           'M', '1984-02-28', '2011-01-20', 34000,     0, 'SECRETARIO',        '34.567.890','5000'),
('50.000.004', 'Teresa Sampedro Oliva',          'F', '1990-03-12', '2016-06-20', 26000,     0, 'SECRETARIA',        '34.567.890','5000'),
('50.000.005', 'Paula Prieto Llorente',          'F', '1986-10-14', '2012-03-12', 28000,     0, 'TEC. RRHH',         '34.567.890','5000'),

--  FINANZAS (6000)
('45.678.901', 'Javier Vega Carrillo',           'M', '1972-12-12', '2003-06-01', 88000,     0, 'JEFE FINANZAS',     NULL,        '6000'),
('60.000.001', 'Alfonso Bravo Cuesta',           'M', '1979-08-08', '2006-02-02', 42000,     0, 'CONTABLE',          '45.678.901','6000'),
('60.000.002', 'Clara Mendoza Fuentes',          'F', '1985-10-18', '2010-09-09', 41000,     0, 'CONTABLE',          '45.678.901','6000'),
('60.000.003', 'Nuria Abril Pizarro',            'F', '1990-01-30', '2015-04-04', 23000,     0, 'ANALISTA FIN.',     '45.678.901','6000'),
('60.000.004', 'Raúl Castaño Zamora',            'M', '1988-08-20', '2013-01-22', 39000,     0, 'CONTABLE',          '45.678.901','6000'),

--  LOGÍSTICA (7000)
('56.789.012', 'Patricia Peña Escribano',        'F', '1976-02-23', '2004-03-20', 72000, 2000, 'JEFE LOGIST.',      NULL,        '7000'),
('70.000.001', 'Óscar Torres Requena',           'M', '1983-03-03', '2009-06-06', 32000, 2000, 'OPER. LOGIST.',     '56.789.012','7000'),
('70.000.002', 'Paula Crespo Salmerón',          'F', '1986-07-27', '2011-11-11', 31000, 1500, 'OPER. LOGIST.',     '56.789.012','7000'),
('70.000.003', 'Julia Morales Roldán',           'F', '1991-12-12', '2016-10-10', 22000,    0, 'OPER. LOGIST.',     '56.789.012','7000'),
('70.000.004', 'Ignacio Cebrián Tejada',         'M', '1984-05-21', '2010-07-18', 33500, 1000, 'OPER. LOGIST.',     '56.789.012','7000'),

--  MARKETING (8000)
('67.890.123', 'Marina Sánchez Hurtado',         'F', '1981-06-14', '2008-02-10', 76000, 5000, 'JEFE MKT',          NULL,        '8000'),
('80.000.001', 'Álvaro Romero Jurado',           'M', '1984-04-14', '2010-03-03', 36000, 3000, 'TEC. MARKETING',    '67.890.123','8000'),
('80.000.002', 'Beatriz Calvo Manzano',          'F', '1988-08-24', '2012-07-07', 37000, 2500, 'TEC. MARKETING',    '67.890.123','8000'),
('80.000.003', 'Gloria Serrano Puerta',          'F', '1992-02-02', '2017-09-09', 21000,    0, 'ANALISTA MKT',      '67.890.123','8000'),
('80.000.004', 'Sergio Vargas Iriarte',          'M', '1987-01-15', '2011-06-10', 39000, 1500, 'TEC. MARKETING',    '67.890.123','8000'),

--  SISTEMAS (9000)
('78.901.234', 'Sergio Navarro Aguilar',         'M', '1982-04-18', '2006-07-01', 74000,    0, 'JEFE SISTEMAS',     NULL,        '9000'),
('90.000.001', 'Iván Saldaña Rivera',            'M', '1983-05-05', '2009-12-12', 46000,    0, 'ADMIN SIST.',       '78.901.234','9000'),
('90.000.002', 'Teresa Murillo Torres',          'F', '1987-03-21', '2011-08-08', 44000,    0, 'SOPORTE',           '78.901.234','9000'),
('90.000.003', 'Germán Pino Ferrer',             'M', '1991-11-11', '2018-01-01', 26000,    0, 'SOPORTE',           '78.901.234','9000'),
('90.000.004', 'Roberto Álvarez Mena',           'M', '1986-01-15', '2012-03-01', 47000,    0, 'ADMIN SIST.',       '78.901.234','9000'),
('90.000.005', 'Elisa Candel Ortega',            'F', '1989-04-19', '2014-05-22', 35000,    0, 'SOPORTE',           '78.901.234','9000'),

--  CALIDAD (9100)
('89.012.345', 'César Ruiz Benavente',           'M', '1979-09-09', '2007-07-01', 65000,    0, 'JEFE CALIDAD',      NULL,        '9100'),
('91.000.001', 'Laura Espinosa Valverde',        'F', '1986-03-15', '2012-02-01', 32000, 1000, 'TEC. CALIDAD',      '89.012.345','9100'),
('91.000.002', 'Andrés Collado Parra',           'M', '1988-10-22', '2014-09-10', 31000,  800, 'TEC. CALIDAD',      '89.012.345','9100');



-- 3. Obtener los datos completos de los empleados.
SELECT *FROM empleado;


-- 4. Obtener los datos completos de los departamentos.
SELECT *FROM departamento;


-- 5. Obtener los datos de los empleados con cargo 'Secretaria’ / ‘Secretario’.

SELECT * FROM empleado WHERE cargoE LIKE 'SECRETAR%';


-- 6. Obtener el nombre y salario de los empleados.

SELECT nomEmp, salEmp FROM empleado;


-- 7. Obtener los datos de los vendedores, ordenado por nombre.

SELECT * FROM empleado WHERE cargoE LIKE 'VENDED%' ORDER BY nomEmp;

-- 8. Listar el nombre de los departamentos, ordenado por nombre y ciudad en orden ascendente, descendente.

SELECT nombreDpto, Ciudad FROM departamento ORDER BY nombreDpto ASC, Ciudad DESC;


-- 9. Obtener el nombre y cargo de los empleados, ordenado por cargo y salario

SELECT nomEmp, cargoE, salEmp FROM empleado ORDER BY cargoE, salEmp;


-- 10. Listar el nombre del departamento cuya suma de salarios sea la más alta.

SELECT d.nombreDpto, SUM(e.salEmp) AS total_salarios
FROM empleado e
JOIN departamento d ON e.codDepto = d.codDepto
GROUP BY d.codDepto, d.nombreDpto
ORDER BY total_salarios DESC
LIMIT 1;


-- 11. Listar los salarios y comisiones de los empleados del departamento 2000, ordenado por comisión.

SELECT salEmp, comisionE FROM empleado WHERE codDepto = '2000' ORDER BY comisionE;


-- 12. Listar todas las comisiones que sean diferentes, ordenada por valor.

SELECT DISTINCT comisionE FROM empleado ORDER BY comisionE;


-- 13. Listar los diferentes salarios.

SELECT DISTINCT salEmp FROM empleado;


-- 14. Obtener el valor total a pagar que resulta de sumar a los empleados del departamento ‘3000’ una bonificación de 5.000€, en orden alfabético del empleado.

SELECT nomEmp, salEmp + 5000 AS total_pagar FROM empleado WHERE codDepto = '3000' ORDER BY nomEmp;


-- 15. Obtener la lista de los empleados que ganan una comisión superior a su sueldo.

SELECT * FROM empleado WHERE comisionE > salEmp;


-- 16. Listar los empleados cuya comisión es menor o igual que el 30% de su sueldo

SELECT * FROM empleado WHERE comisionE <= salEmp * 0.30;


-- 17. Listar los empleados cuyo salario es menor o igual que el 40% de su comisión.

SELECT * FROM empleado WHERE salEmp <= comisionE * 0.40;


-- 18. Listar el salario, la comisión, el salario total (salario + comisión), documento de identidad del empleado y nombre, de aquellos empleados que 
-- tienen comisión superior a 10.000 €, ordenar el informe por el número del documento de identidad.

SELECT salEmp, comisionE, salEmp + comisionE AS salario_total, nDIEmp, nomEmp FROM empleado WHERE comisionE > 10000 ORDER BY nDIEmp;


-- 19. Hallar el nombre de los empleados que tienen un salario superior a 50.000 €, y tienen como jefe al empleado con documento de identidad '31.840.269’.

SELECT nomEmp FROM empleado WHERE salEmp > 50000 AND jefeID = '31.840.269';


-- 20. Obtener los nombres de los departamentos que no sean 'VENTAS', 'INVESTIGACIÓN', ni 'MANTENIMIENTO', ordenados por ciudad.

SELECT nombreDpto, Ciudad FROM departamento WHERE nombreDpto NOT IN ('VENTAS','INVESTIGACIÓN','MANTENIMIENTO') ORDER BY Ciudad;


-- 21. Listar los datos de los empleados cuyo nombre (inicia por la letra 'M’), AND (su salario es mayor a 40.000 OR reciben comisión) AND y trabajan para el 
-- departamento de 'VENTAS’.

SELECT * FROM empleado WHERE nomEmp LIKE 'M%' AND (salEmp > 40000 OR comisionE > 0) AND codDepto = '3000';


-- 22. Obtener nombre, salario y comisión de los empleados que reciben un salario situado entre la mitad de la comisión la propia comisión.

SELECT nomEmp, salEmp, comisionE FROM empleado WHERE salEmp BETWEEN comisionE / 2 AND comisionE;


-- 23. Entregar el salario más alto de la empresa.

SELECT MAX(salEmp) AS salario_mas_alto FROM empleado;


-- 24. Entregar el total a pagar por comisiones, y el número de empleados que las reciben.

SELECT SUM(comisionE) AS total_comisiones, COUNT(*) AS empleados_con_comision FROM empleado WHERE comisionE > 0;


-- 25. Hallar el salario más alto, el más bajo y la diferencia entre ellos.

SELECT MAX(salEmp), MIN(salEmp), MAX(salEmp)-MIN(SalEMp) as diferencia FROM empleado;


-- 26. Entregar el número de empleados de sexo femenino y de sexo masculino, por departamento

SELECT d.nombreDpto,
    SUM(CASE WHEN e.sexEmp = 'F' THEN 1 ELSE 0 END) AS mujeres,
    SUM(CASE WHEN e.sexEmp = 'M' THEN 1 ELSE 0 END) AS hombres
FROM empleado e
INNER JOIN departamento d ON e.codDepto = d.codDepto
GROUP BY d.codDepto, d.nombreDpto;


-- 27. Hallar el salario promedio por departamento.

SELECT d.nombreDpto, AVG(e.salEmp) AS salario_promedio
FROM empleado e
INNER JOIN departamento d ON e.codDepto = d.codDepto
GROUP BY d.codDepto, d.nombreDpto;


-- 28. Entregar un reporte con el número de cargos en cada departamento y cual es el promedio de salario de cada uno. Indicar el nombre del departamento en el resultado.

SELECT d.nombreDpto,
    COUNT(e.nDIEmp) AS numero_cargos,
    AVG(e.salEmp) AS salario_promedio
FROM empleado e
INNER JOIN departamento d ON e.codDepto = d.codDepto
GROUP BY d.codDepto, d.nombreDpto;


-- 29. Calcular el total de salarios por departamento.

SELECT d.nombreDpto, SUM(e.salEmp) AS total_salarios
FROM empleado e
INNER JOIN departamento d ON e.codDepto = d.codDepto
GROUP BY d.codDepto, d.nombreDpto;


-- 30. Hallar la suma de salarios más alta, crear para ello una vista

CREATE VIEW vista_salarios_departamento AS
SELECT d.nombreDpto, SUM(e.salEmp) AS total_salarios
FROM empleado e
INNER JOIN departamento d ON e.codDepto = d.codDepto
GROUP BY d.nombreDpto;

SELECT *
FROM vista_salarios_departamento
ORDER BY total_salarios DESC
LIMIT 1;
















