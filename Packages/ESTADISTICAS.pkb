CREATE OR REPLACE PACKAGE BODY UNIVERSO.ESTADISTICAS IS

PROCEDURE INFO_MES (MES IN VARCHAR2, HEMIS IN VARCHAR2) IS
    CURSOR C_CONSTELACION IS SELECT NOMBRE_POPULAR, MES_MEJOR_VIS, GENITIVO, HEMISFERIO FROM CONSTELACIONES 
                             WHERE MES=MES_MEJOR_VIS AND HEMISFERIO=HEMIS;                      
    V_GEN CONSTELACIONES.GENITIVO%TYPE;
    
    CURSOR C_OBJETOS IS SELECT NUM_CATALOGO, NOM_OBJETO FROM OBJETOS WHERE GENITIVO_CONST_OBJ=V_GEN;
    
    CURSOR C_ASTERISMOS IS SELECT NOM_ASTERISMO, GENITIVO_CONST_EST FROM ASTERISMOS, ESTRELLAS 
                        WHERE NOM_ASTERISMO=NOMBRE_ASTERISMO AND GENITIVO_CONST_EST=V_GEN;
    CURSOR C_LLUVIA IS SELECT NOMBRE_LLUVIA, RADIANTE, GENITIVO_CONST_LLUVIA FROM LLUVIA_ESTRELLAS
                        WHERE GENITIVO_CONST_LLUVIA=V_GEN;
    ERROR_NULL EXCEPTION;
    ERROR_HEMIS EXCEPTION;
    ERROR_MES EXCEPTION;
    
    BEGIN
        IF MES IS NULL OR HEMIS IS NULL THEN
            RAISE ERROR_NULL;
        ELSIF HEMIS !='NORTE' AND HEMIS !='SUR' THEN
            RAISE ERROR_HEMIS;
        ELSIF MES!='ENERO' AND MES!='FEBRERO' AND MES!='MARZO' AND MES!='ABRIL' AND MES!='MAYO' AND MES!='JUNIO' AND MES!='JULIO' AND
              MES!='AGOSTO' AND MES!='SEPTIEMBRE' AND MES!='OCTUBRE' AND MES!='NOVIEMBRE' AND MES!='DICIEMBRE' THEN
            RAISE ERROR_MES;
        ELSE
            DBMS_OUTPUT.PUT_LINE(' ******** ' ||MES|| ' ********');
            FOR i IN C_CONSTELACION
            LOOP
                DBMS_OUTPUT.PUT_LINE(C_CONSTELACION%ROWCOUNT||'. '||i.NOMBRE_POPULAR||' ('||LOWER(i.GENITIVO)||').');
                V_GEN:=i.GENITIVO;
                FOR j IN C_OBJETOS
                LOOP  
                    DBMS_OUTPUT.PUT_LINE('- Objeto: '||j.NUM_CATALOGO||'. '||j.NOM_OBJETO); 
                END LOOP;
                FOR n IN C_ASTERISMOS
                LOOP
                    DBMS_OUTPUT.PUT_LINE('- Asterismo: '||n.NOM_ASTERISMO);
                END LOOP;
                FOR y IN C_LLUVIA
                LOOP
                    DBMS_OUTPUT.PUT_LINE('- Lluvia de estrellas: '||y.NOMBRE_LLUVIA||' ('||y.RADIANTE||')');
                END LOOP;
           END LOOP;
       END IF;
EXCEPTION
    WHEN ERROR_NULL THEN
    RAISE_APPLICATION_ERROR(-20000,'Faltan par�metros');
    WHEN ERROR_HEMIS THEN
    RAISE_APPLICATION_ERROR(-20001,'Hemisferio incorrecto');
    WHEN ERROR_MES THEN
    RAISE_APPLICATION_ERROR(-20002,'Mes incorrecto');
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20002,'Ha ocurrido un error');
    
    END INFO_MES;
    
FUNCTION VISIBILIDAD (TIPO IN VARCHAR2, NOM IN VARCHAR2) RETURN VARCHAR2
IS
V_REG NUMBER (10);
ERROR_NULL EXCEPTION;
TIPO_INCORRECTO EXCEPTION;
BEGIN
    CASE
        WHEN TIPO IS NULL OR NOM IS NULL THEN
            RAISE ERROR_NULL;
        WHEN TIPO='ESTRELLA' THEN
            SELECT MAGNITUD INTO V_REG FROM ESTRELLAS WHERE NOM_ESTRELLA=NOM;
        WHEN TIPO='OBJETO' THEN
            SELECT MAGNITUD INTO V_REG FROM OBJETOS WHERE NOM_OBJETO=NOM OR NOM=NUM_CATALOGO;
        ELSE 
            RAISE TIPO_INCORRECTO;
    END CASE;
    
    IF INSTR(V_REG,'EL ')>0 THEN
        V_REG:=REPLACE(V_REG,'EL ');
    ELSIF INSTR(V_REG,'LA ')>0 THEN
        V_REG:=REPLACE(V_REG,'LA ');
    END IF;
    
    IF V_REG <=4 THEN RETURN 'EN CIELO URBANO';
    ELSIF V_REG >4 AND V_REG <=6 THEN RETURN 'EN CIELO PERIURBANO';
    ELSIF V_REG >6 AND V_REG <=8 THEN RETURN 'EN CIELO OSCURO';
    ELSE RETURN 'FUERA DE ALCANCE DEL OJO HUMANO';
    END IF;
    
EXCEPTION
    WHEN ERROR_NULL THEN
    RAISE_APPLICATION_ERROR(-20005, 'Faltan par�metros.');
    WHEN  TIPO_INCORRECTO THEN
    RAISE_APPLICATION_ERROR(-20004, 'El tipo debe ser objeto o estrella');
    WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR (-20002, 'La objeto o estrella no existe');
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20003, 'Ha ocurrido un error');
  
END VISIBILIDAD;

PROCEDURE RESULTADO_IMAGENES (NUM IN NUMBER)
IS

CURSOR C_IMAGENES IS SELECT NUM_IMAGEN FROM IMAGEN WHERE NUM_IMAGEN=NUM;
V_REG OBJETOS.NUM_CATALOGO%TYPE;
NO_EXISTE NUMBER;
ERROR_NODATA EXCEPTION;

BEGIN
    SELECT COUNT(*) INTO NO_EXISTE FROM IMAGEN WHERE NUM_IMAGEN=NUM;
    IF NO_EXISTE=0 THEN 
        RAISE ERROR_NODATA; 
    ELSE
        FOR i IN C_IMAGENES 
        LOOP

            DBMS_OUTPUT.PUT_LINE('ID Imagen: '||i.NUM_IMAGEN);
            FOR j IN (SELECT NUM_IMAGEN_REP,NOM_OBJETO, NUM_CATALOGO FROM REPRESENTAR, OBJETOS 
                      WHERE NUM_IMAGEN_REP=i.NUM_IMAGEN AND NUM_OBJETO_REP=NUM_CATALOGO) 
            LOOP
                DBMS_OUTPUT.PUT_LINE('Objeto: '|| j.NOM_OBJETO);
                SELECT NUM_CATALOGO INTO V_REG FROM OBJETOS WHERE NUM_CATALOGO=j.NUM_CATALOGO;
            END LOOP;
            FOR y IN (SELECT NUM_IMAGEN_CAT, GENITIVO_CAT, NOM_ESTRELLA FROM CATALOGAR, CONSTELACIONES, ESTRELLAS
                      WHERE NUM_IMAGEN_CAT=i.NUM_IMAGEN AND GENITIVO_CAT=GENITIVO AND GENITIVO=GENITIVO_CONST_EST
                      AND (V_REG=NUM_CAT_CUMULO OR V_REG=NUM_CAT_NEBULOSA))
            LOOP
                DBMS_OUTPUT.PUT_LINE('Estrella: '||y.NOM_ESTRELLA);
            END LOOP;

        END LOOP;
    END IF;
    
EXCEPTION
    WHEN ERROR_NODATA THEN
    RAISE_APPLICATION_ERROR(-20111,'El n�mero de imagen no existe');
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20110,'Ha ocurrido un error');

END RESULTADO_IMAGENES;

PROCEDURE BUSCAR_ESTRELLAS (LET IN VARCHAR2,GEN IN VARCHAR2,NOM IN VARCHAR2)
IS
S_SQL VARCHAR2 (4000);
ERROR_NULL EXCEPTION;
BEGIN
        
    IF LET IS NULL AND GEN IS NULL AND NOM IS NULL THEN
       RAISE ERROR_NULL;
    ELSE
       S_SQL:='DECLARE CURSOR C_ESTRELLAS IS SELECT * FROM ESTRELLAS WHERE ';
       IF LET IS NOT NULL THEN
           S_SQL:=S_SQL||' LETRA='||chr(39)||LET||chr(39);
       END IF;
       IF GEN IS NOT NULL THEN
           IF LET IS NOT NULL THEN
               S_SQL:=S_SQL||' AND GENITIVO_CONST_EST='||chr(39)||GEN||chr(39);
           ELSE
               S_SQL:=S_SQL||' GENITIVO_CONST_EST='||chr(39)||GEN||chr(39);
           END IF;
       END IF;
       IF NOM IS NOT NULL THEN
           IF LET IS NOT NULL OR GEN IS NOT NULL THEN
               S_SQL:=S_SQL||' AND NOM_ESTRELLA='||chr(39)||NOM||chr(39);
           ELSE
               S_SQL:=S_SQL||' NOM_ESTRELLA='||chr(39)||NOM||chr(39);
           END IF;
       END IF;
    END IF;
        
    S_SQL:= S_SQL||'; BEGIN 
                        FOR i IN C_ESTRELLAS 
                        LOOP
                            DBMS_OUTPUT.PUT_LINE(i.LETRA ||'' ''||i.GENITIVO_CONST_EST ||'', ''||i.NOM_ESTRELLA); 
                        END LOOP;
                        END;';
EXECUTE IMMEDIATE S_SQL;
EXCEPTION
    WHEN ERROR_NULL THEN
    RAISE_APPLICATION_ERROR(-20100, 'No has introducido ning�n campo');
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20100, 'Ha ocurrido un error');
END BUSCAR_ESTRELLAS;
END ESTADISTICAS; 
/
