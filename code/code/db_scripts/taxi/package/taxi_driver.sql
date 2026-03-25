CREATE OR REPLACE PACKAGE TAXI_SHAPOSHNIKOV.taxi_driver
  as
   
 PROCEDURE RENTAUTO(DRIVERID IN NUMBER, newcar OUT NUMBER, rent_id OUT number);
 PROCEDURE CREATEORDER(
 mypassengerID in NUMBER, 
 start_point IN NUMBER,
 addrVarray IN VARCHAR,
 amountToPaid IN float,
 currency IN NUMBER,
 driverId IN NUMBER,
 typeofPaid IN varchar
);


PROCEDURE GET_ADDRESS(addrVarray IN VARCHAR, y OUT varchar);
PROCEDURE GET_ADDRESS_TOGO(startPoint NUMBER, addrVarray IN VARCHAR, orderId IN NUMBER);
PROCEDURE PARKING_P(addrVarray IN VARCHAR, carid IN number);
PROCEDURE REFUELLING_1(
P25_DRIVERID IN NUMBER, 
P25_CARID IN NUMBER,
P25_PAY_CURRENCY IN NUMBER,
P25_PAY_METHOD IN varchar,
P25_GAS IN float,
P25_ID_ADDR IN NUMBER,
P25_PAID IN float);
PROCEDURE RENTAUTO_OUT(CARID IN NUMBER, fuel_out in FLOAT, go_distance in float, rent_id IN number);
FUNCTION CHANGEORDERSTATUS(ORDER_ID IN NUMBER,PAS_ID IN NUMBER,DR_ID IN NUMBER) RETURN VARCHAR;
FUNCTION CREATENEWORDER(
PAS_ID IN NUMBER,
D_ID IN NUMBER, 
T_CREATE IN DATE,
STA IN VARCHAR, 
PAY_ID IN VARCHAR,
CUR_ID IN NUMBER,
TYPE_PAID IN VARCHAR,
COST IN FLOAT,
AVD IN FLOAT) 
RETURN NUMBER;

PROCEDURE get_mile_cost(
addrVarray IN varchar, -- получаю точки адреса (остановки)
mileage OUT float, -- отдаю расстояние
cost OUT float -- отдаю стоимость
);

PROCEDURE N3PLUS1_KOLATZ(a in number);


END taxi_driver;

CREATE OR REPLACE PACKAGE BODY TAXI_SHAPOSHNIKOV.taxi_driver
  AS

PROCEDURE RENTAUTO(DRIVERID IN NUMBER, newcar OUT NUMBER, rent_id OUT number) 
is

rent_date DATE;

BEGIN
		
	select c.id into newcar from car c 
	                        where c.is_reserved <> 1
	                        order by 1 FETCH NEXT 1 ROWS ONLY;

    update car c set c.is_reserved = 1 where c.id in (newcar); 
   	SELECT sysdate INTO rent_date FROM dual;
	INSERT INTO RENT T (T.DRIVER_ID,T.CAR_ID,T.DATE_START) VALUES (DRIVERID,newcar,rent_date);
	SELECT t.id INTO rent_id FROM rent t WHERE t.DRIVER_ID =DRIVER_ID and t.CAR_ID =newcar AND t.DATE_START  = rent_date;
    
 DBMS_OUTPUT.put_line ('Такси найдено. Поехали!');
 EXCEPTION
            WHEN NO_DATA_FOUND THEN    -- если авто нет, пишем что пичалька и даем ошибку
            DBMS_OUTPUT.PUT_LINE('NO FREE CARS OR CANT FIND THIS DRIVER');
            WHEN OTHERS THEN
                  DBMS_OUTPUT.put_line ('Стек ошибок верхнего уровня:');
      				DBMS_OUTPUT.put_line (DBMS_UTILITY.format_error_backtrace);
      			END RENTAUTO;
      		
      		

PROCEDURE CREATEORDER(
 mypassengerID in NUMBER, 
 start_point IN NUMBER,
 addrVarray IN VARCHAR,
 amountToPaid IN float,
 currency IN NUMBER,
 driverId IN NUMBER,
 typeofPaid IN varchar
) AS

    PASSENGER_ID NUMBER:=mypassengerID;                          -- ID пассажира
    ----------------------------------------------------------------------
    PAYMENT_ID VARCHAR(25) := DBMS_RANDOM.STRING('P',10);   -- ID платежа
    AVERAGE_DRIVER_SPEED_N NUMBER :=DBMS_RANDOM.value(1,190);
    order_id NUMBER;     
    EXISTERROR EXCEPTION;
    
    BEGIN

	      	-- добавляем платежную информацию
	        INSERT INTO PAYMENT P (P.ID, P.CURRENCY_ID, P.TYPE, P.AMOUNT_TO_PAID, P.TIME_CREATE)
			VALUES (PAYMENT_ID,currency,typeofPaid,amountToPaid,SYSDATE);
		
			DBMS_OUTPUT.PUT_LINE(SYSDATE || 'COST IS ' || amountToPaid); 
	        
			-- создаем новый заказ
            INSERT INTO IS_ORDER (PASSENGER_ID, DRIVER_ID, TIME_CREATE, STATUS,PAYMENT_ID,AVERAGE_DRIVER_SPEED)
            VALUES (mypassengerID,driverId, sysdate, 'search_driver', PAYMENT_ID,AVERAGE_DRIVER_SPEED_N );
           
           	-- получаем только что созданный Номер заказа
            ORDER_ID := get_order_id(PAYMENT_ID,'search_driver');
           
           	-- записываем маршрутную информацию
			GET_ADDRESS_TOGO(start_point, addrVarray, ORDER_ID);

			-- 
			DBMS_OUTPUT.PUT_LINE(CHANGEORDERSTATUS(ORDER_ID, mypassengerID, driverId));
			
		-----------------------------------------------------------------------------------------
		-- переделать закрытие заказа
		-- параметры:
		-- ORDER_ID := get_order_id(PAYMENT_ID,'search_driver');
		-- driver_id
		-- payment_id
		
		 	UPDATE IS_ORDER O SET   O.TIME_END = SYSDATE,
                                        O.STATUS = 'trip_completed',
                                        O.END_TRIP_ADDRESS = 1
                WHERE O.ID = ORDER_ID AND O.DRIVER_ID = DRIVER_ID and o.PAYMENT_ID = PAYMENT_ID;
           
                DBMS_OUTPUT.PUT_LINE('TRIP COMPLETED');
         
		
		-----------------------------------------------------------------------------------------

        EXCEPTION
            WHEN EXISTERROR THEN
                DBMS_OUTPUT.PUT_LINE('I SAW AN ERROR WITH CREATE NEW ORDER' /*IN VARCHAR2*/);
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('I cant FOUND ANY INFORMATION');
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('ANOTHER ERROR' /*IN VARCHAR2*/);
                                DBMS_OUTPUT.put_line ('Стек ошибок верхнего уровня:');
      				DBMS_OUTPUT.put_line (DBMS_UTILITY.format_error_backtrace);
END CREATEORDER;


PROCEDURE GET_ADDRESS(addrVarray IN VARCHAR, y OUT varchar)
AS

names addr_points;
counter NUMBER;
x varchar(200);
--y varchar(200);

BEGIN
 
names := addr_points();
counter:=regexp_count(addrVarray,'[^:]+',1);	
	
		FOR i in 1 .. counter LOOP
			x:=regexp_substr(addrVarray, '[^:]+',1,i);
			--	dbms_output.put_line(x);
	-- /////////////////////////////////////////////////////////////
			names.extend;
			names(i) := x;
			-- dbms_output.put_line(names(i));
	--	dbms_output.put_line(y);
	
		SELECT CONCAT(concat(CONCAT(CONCAT(CONCAT(CONCAT(c.name,' ,г.'),c2.name),' ,ул.'),s.name),' ,д.'),a.house_number) AS full_address
		INTO y FROM COUNTRY c 
			JOIN CITY c2 ON c.ID =c2.COUNTRY_ID 
			JOIN STREET s ON s.CITY_ID = c2.ID	
			JOIN ADDRESS a ON a.STREET_ID = s.ID
		WHERE a.id = x;
		dbms_output.put_line(y);
		END LOOP;

END GET_ADDRESS;

PROCEDURE GET_ADDRESS_TOGO(startPoint NUMBER, addrVarray IN VARCHAR, orderId IN NUMBER)
AS
names addr_points;
counter NUMBER;
-- ADDR_ARRAY varchar(200):='10:350:34:17:59:53:9:013:33:423423';
x varchar(200);
TOTAL NUMBER;
n_last NUMBER;
n_prior NUMBER;

mileage float;


BEGIN
 
names := addr_points();
counter:=regexp_count(addrVarray,'[^:]+',1);	
mileage:=0;	
INSERT INTO way w (w.FROM_ADDRESS_ID,w.TO_ADDRESS_ID,w.DISTANCE,w.ORDER_ID) VALUES (startPoint, 1, 30, orderId);

		FOR i in 1 .. counter LOOP
			x:=regexp_substr(addrVarray, '[^:]+',1,i);
			names.extend;
			names(i) := x;
		dbms_output.put_line(names(i));
		total:=names.count;
		mileage:=mileage+names(i);
		END LOOP;
		n_last:=names(names.last);
		n_prior:=names(names.PRIOR(names.LAST));
		--dbms_output.put_line(n_last);
		--dbms_output.put_line(n_prior);
		--dbms_output.put_line(mileage);
		UPDATE way w SET w.POINT_TO_GO = (names), w.TO_ADDRESS_ID = n_last,
						 w.PREVIEW_WAY_ID = n_prior
			WHERE w.ORDER_ID = orderId; 
	--	INSERT INTO PARKING p2 (p2."number",p2.ADDRESS_ID) VALUES (uk_number, n_last);
		END GET_ADDRESS_TOGO;
	
PROCEDURE PARKING_P(addrVarray IN VARCHAR, carid IN number)
IS

uk_number number(30) := dbms_random.value(10000000,99999999);
names addr_points;
counter NUMBER;
x varchar(200);

n_last NUMBER;

BEGIN
 
names := addr_points();
counter:=regexp_count(addrVarray,'[^:]+',1);	

		FOR i in 1 .. counter LOOP
			x:=regexp_substr(addrVarray, '[^:]+',1,i);
			names.extend;
			names(i) := x;
		dbms_output.put_line(names(i));

		END LOOP;
		n_last:=names(names.last);
INSERT INTO PARKING p2 (p2."number",p2.ADDRESS_ID) VALUES (uk_number, n_last);
UPDATE CAR c SET c.PARKING_ID = n_last WHERE c.ID = carid;
END PARKING_P;

	
PROCEDURE REFUELLING_1(


P25_DRIVERID IN NUMBER, 
P25_CARID IN NUMBER,
P25_PAY_CURRENCY IN NUMBER,
P25_PAY_METHOD IN varchar,
P25_GAS IN float,
P25_ID_ADDR IN NUMBER,
P25_PAID IN float) 

AS

-- id авто
-- сумма к оплате
-- валюта
-- Тип оплаты
-- кол-во бензина
-- создает запись в refueling и payment

P25_ID_PAYMENT VARCHAR(25) := DBMS_RANDOM.STRING('P',10);
P25_PERCENT_OF_PAID FLOAT;
-- id_curr NUMBER;
-- paid_type NUMBER;
-- gas_paid float;
-- id_car NUMBER;
-- gas float;
-- id_addr NUMBER;

BEGIN

SELECT D.PERCENT_OF_PAYMENT INTO P25_PERCENT_OF_PAID FROM DRIVER d WHERE D.ID = P25_DRIVERID;

	   
INSERT INTO PAYMENT P (P.ID, P.CURRENCY_ID, P.TYPE, P.AMOUNT_TO_PAID, P.TIME_CREATE)
			VALUES (P25_ID_PAYMENT,P25_PAY_CURRENCY,P25_PAY_METHOD,P25_PAID*(P25_PERCENT_OF_PAID*0.01),SYSDATE);

INSERT INTO REFUELLING r (
r.DRIVER_ID, 
r.CAR_ID, 
r.PAYMENT_ID, 
r.AMOUNT_OF_GASOLINE, 
r.ADDRESS_ID)
VALUES (P25_DRIVERID, P25_CARID, P25_ID_PAYMENT, P25_GAS, P25_ID_ADDR);

EXCEPTION
   WHEN NO_DATA_FOUND THEN    -- если авто нет, пишем что пичалька и даем ошибку
   DBMS_OUTPUT.PUT_LINE('SOMETHING WRONG!');
   WHEN OTHERS THEN
   DBMS_OUTPUT.put_line ('Стек ошибок верхнего уровня:');
   DBMS_OUTPUT.put_line (DBMS_UTILITY.format_error_backtrace);
END REFUELLING_1;


PROCEDURE RENTAUTO_OUT(
CARID IN NUMBER, 
fuel_out in FLOAT, 
go_distance in float,
rent_id IN number
)  AS

cursor neko (ext_id NUMBER)
      IS
      SELECT c.ID, c.is_reserved FROM car c      -- e.FIRST_NAME,e.LAST_NAME,e.SALARY,
      WHERE c.id IN (ext_id);

       foundcar number;
       driver number;

      ISRESERVED EXCEPTION;

BEGIN
    FOR r IN neko(CARID) LOOP
                        BEGIN
                        IF r.is_reserved = 0 THEN RAISE ISRESERVED;
----------------------------------------------------------------------
                        ELSE

                            UPDATE RENT R SET  R.DISTANCE =  go_distance,
                                                R.GAS_MILEAGE = FUEL_OUT,
                                                R.date_stop = SYSDATE
                                                WHERE R.CAR_ID = CARID
                                                AND r.ID = rent_id;
                            UPDATE CAR C SET C.IS_RESERVED = 0 WHERE C.ID = CARID;
                            UPDATE car c set c.mileage = C.MILEAGE+go_distance where c.id = carid;
                        END IF;

                EXCEPTION
                        WHEN ISRESERVED THEN
                            DBMS_OUTPUT.PUT_LINE('This auto is already rent out');
                          WHEN NO_DATA_FOUND THEN
                                DBMS_OUTPUT.put_line('not found car with ID ' || CARID);
                                WHEN OTHERS THEN
                                DBMS_OUTPUT.put_line('your car is ID ' || CARID);
                            CONTINUE;
                            END;
                  END LOOP;
END RENTAUTO_OUT;


FUNCTION CHANGEORDERSTATUS(
                                        ORDER_ID IN NUMBER,
                                        PAS_ID IN NUMBER,
                                        DR_ID IN NUMBER) RETURN VARCHAR  -- верхем сообщение
IS

   type namesarray IS VARRAY(3) OF VARCHAR2(25);
   names namesarray;
   total INTEGER;
   IS_SUCCESS VARCHAR(50);
BEGIN
            names := namesarray('wait_passenger','wait_payment');
            total := names.count;

            FOR i in 1 .. total LOOP

                 UPDATE IS_ORDER O SET  O.STATUS = NAMES(I)
                     WHERE O.ID = ORDER_ID AND O.DRIVER_ID = DR_ID AND O.PASSENGER_ID = PAS_ID;
                     DBMS_OUTPUT.PUT_LINE('STATUS IS ' || names(i) || ' NOW');
                     N3PLUS1_KOLATZ(1);
            END LOOP;
            IS_SUCCESS:='STATUS WAS UPDATE';
            RETURN IS_SUCCESS;
END CHANGEORDERSTATUS;

FUNCTION CREATENEWORDER(
PAS_ID IN NUMBER,
D_ID IN NUMBER, 
T_CREATE IN DATE,
STA IN VARCHAR, 
PAY_ID IN VARCHAR,
CUR_ID IN NUMBER,
TYPE_PAID IN VARCHAR,
COST IN FLOAT,
AVD IN FLOAT) 

RETURN NUMBER
IS

    OUT_ORDER_ID NUMBER;

        BEGIN
	       
	        
	        INSERT INTO PAYMENT P (P.ID, P.CURRENCY_ID, P.TYPE, P.AMOUNT_TO_PAID, P.TIME_CREATE)
			VALUES (PAY_ID,CUR_ID,TYPE_PAID,COST,SYSDATE);
		
			DBMS_OUTPUT.PUT_LINE(SYSDATE || 'COST IS ' || COST); 
	        
            INSERT INTO IS_ORDER (PASSENGER_ID, DRIVER_ID, TIME_CREATE, STATUS,PAYMENT_ID,AVERAGE_DRIVER_SPEED)
            VALUES (PAS_ID,D_ID,T_CREATE, STA, PAY_ID, AVD);

            SELECT distinct O.ID INTO OUT_ORDER_ID FROM IS_ORDER O 
	                WHERE O.DRIVER_ID = D_ID
	                AND O.PASSENGER_ID = PAS_ID
	                AND o.PAYMENT_ID = PAY_ID
	               AND O.STATUS = STA
               order by 1 FETCH NEXT 1 ROWS ONLY;
                
            RETURN OUT_ORDER_ID;
           
           EXCEPTION
           WHEN NO_DATA_FOUND THEN
	           DBMS_OUTPUT.PUT_LINE('I cant FOUND ANY INFORMATION');
           WHEN OTHERS THEN
	           DBMS_OUTPUT.put_line ('Стек ошибок верхнего уровня:');
	      	   DBMS_OUTPUT.put_line (DBMS_UTILITY.format_error_backtrace);	
END CREATENEWORDER;

PROCEDURE get_mile_cost(
addrVarray IN varchar, -- получаю точки адреса (остановки)
mileage OUT float, -- отдаю расстояние
cost OUT float -- отдаю стоимость
)
AS 

names addr_points;
counter NUMBER;
x varchar(200);
total NUMBER;
mileage_a float;

mileage_cost_a float;

BEGIN
mileage_cost_a:=0.0;
names := addr_points();
counter:=regexp_count(addrVarray,'[^:]+',1);

		FOR i in 1 .. counter LOOP
		
			x:=regexp_substr(addrVarray, '[^:]+',1,i);
			names.extend;
			names(i) := x;

		total:=names.count;
	
		SELECT * INTO mileage_a FROM (SELECT (c.id+c2.id+s.id+a.id)
									FROM COUNTRY c 
										JOIN CITY c2 ON c.ID =c2.COUNTRY_ID 
										JOIN STREET s ON s.CITY_ID = c2.ID	
										JOIN ADDRESS a ON a.STREET_ID = s.ID
										WHERE a.id = names(i)); -- считаю расстояния
					mileage_cost_a:=mileage_cost_a+mileage_a;
					mileage_a:=mileage_a+mileage_a;
		END LOOP;
	
	cost:=mileage_cost_a/10;
	mileage:=mileage_a/100;

END get_mile_cost;


PROCEDURE N3PLUS1_KOLATZ(a in number) AS

x NUMBER := abs(DBMS_RANDOM.RANDOM());
c NUMBER := 0;
m NUMBER := 0;

BEGIN


   WHILE (x > 1) LOOP
    if (MOD(x,2) = 0 ) THEN
      x:= x/2;
      DBMS_OUTPUT.PUT_LINE(c || '  ' ||x);
      INSERT INTO TAXI_SHAPOSHNIKOV.n3p1(step, n) VALUES (c, x);

      c:=c+1;
      else x:= 3*x+1;
      m:=m+1;
      DBMS_OUTPUT.PUT_LINE(c || '  ' ||x);
      INSERT INTO TAXI_SHAPOSHNIKOV.n3p1(step, n) VALUES (c, x);
      c:=c+1;

     END IF;

    END LOOP;
     DBMS_OUTPUT.PUT_LINE(m);


END N3PLUS1_KOLATZ;

END;