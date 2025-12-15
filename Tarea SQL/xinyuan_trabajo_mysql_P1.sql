-- 2.3. ¿Cómo podemos obtener unos resultados totales en una consulta? Por ejemplo, total de una factura a partir de las líneas de detalle de la misma.

USE compras;

SELECT df.idFactura, SUM(df.precioUnitario * df.cantidad) AS total_factura
 FROM detalle_factura df
 GROUP BY df.idFactura;


-- 2.4. ¿Para qué sirve la sentencia GROUP BY? Poner algún ejemplo práctico distinto a los desarrollados en la BD

SELECT idDepartamento, AVG(salario) AS salario_medio
FROM empleado
GROUP BY idEmpleado;


SELECT YEAR(fechaIngreso) AS anio_contratacion,
    COUNT(*) AS num_empleados
FROM empleado
GROUP BY YEAR(fechaIngreso)
ORDER BY anio_contratacion;


-- 2.6. ¿Para qué sirven las SUBQUERIES? Poner algún ejemplo adicional a los desarrollados en la BD.
SELECT idEmpleado, nombre, salario
FROM empleado
WHERE salario > (
    SELECT MAX(salario)
    FROM empleado
    WHERE idDepartamento = 1
);


-- 2.7. Diseñar un TRIGGER que permita insertar datos en una tabla de respaldo para las facturas y líneas de factura. 

CREATE TABLE factura_backup (
    idFactura INT,
    idCliente INT,
    idEmpleado INT,
    fecha DATE,
    fecha_backup DATETIME
);

CREATE TABLE detalle_factura_backup (
    idFactura INT,
    idProducto INT,
    cantidad INT,
    precioUnitario DECIMAL(10,2),
    fecha_backup DATETIME
);

DELIMITER //

CREATE TRIGGER trg_backup_factura
BEFORE DELETE ON factura
FOR EACH ROW
BEGIN
    INSERT INTO factura_backup (idFactura, idCliente, idEmpleado, fecha, fecha_backup)
    VALUES (OLD.idFactura, OLD.idCliente, OLD.idEmpleado, OLD.fecha, NOW());
    
    INSERT INTO detalle_factura_backup (idFactura, idCliente, idEmpleado, fecha, fecha_backup)
    SELECT df.idFactura, df.idProducto, df.cantidad, df.precioUnitario, NOW()
    FROM detalle_factura DF
    WHERE DF.IDFACTURA = OLD.IDFACTURA;
END //
DELIMITER // ;


-- 2.8. Diseñar una VIEW que permita obtener el precio medio de los productos agrupados por categorías. 

CREATE VIEW v_precio_medio_categoria AS
SELECT 
    c.idCategoria,
    c.nombre AS categoria,
    AVG(p.precioUnitario) AS precio_medio
FROM categoria c
INNER JOIN producto p
    ON c.idCategoria = p.idCategoria
GROUP BY c.idCategoria, c.nombre;

SELECT * FROM v_precio_medio_categoria;


-- 2.9. Diseñar un PROCEDURE que al ejecutarse nos determine si se han vendido 3, más de 3 o menos de 3 productos en una transacción de venta.

DELIMITER //

CREATE PROCEDURE sp_evaluar_venta (
    IN p_idFactura INT
)
BEGIN
    DECLARE v_total INT;
    DECLARE v_mensaje VARCHAR(100);

    SELECT IFNULL(SUM(cantidad), 0)
    INTO v_total
    FROM detalle_factura
    WHERE idFactura = p_idFactura;

    IF v_total = 3 THEN
        SET v_mensaje = 'Se han vendido exactamente 3 productos';
    ELSEIF v_total > 3 THEN
        SET v_mensaje = 'Se han vendido más de 3 productos';
    ELSE
        SET v_mensaje = 'Se han vendido menos de 3 productos';
    END IF;


    SELECT 
        p_idFactura    AS idFactura,
        v_total        AS totalProductos,
        v_mensaje      AS mensaje;
END //

DELIMITER //;

CALL sp_evaluar_venta(1);


