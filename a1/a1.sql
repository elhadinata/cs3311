-- Q1
create or replace view Q1(Name, Country) as select name, country from company where country not ilike 'australia';

-- Q2
create or replace view Q2(Code) as select code from executive group by code having count(code) > 5;

-- Q3
create or replace view Q3(Name) as select c.name from company c, category cat where c.code=cat.code and cat.sector ilike 'technology';

-- Q4
create or replace view Q4(Sector, Number) as select sector, count(distinct industry) from category group by sector;

-- Q5
create or replace view Q5(Name) as select person from executive e, category c where e.code=c.code and c.sector ilike 'technology';

-- Q6
create or replace view Q6(Name) as select name from company c, category cat where c.code=cat.code and cat.sector ilike 'services' and c.country ilike 'australia' and c.zip ~ '^2.*';

-- Q7
create or replace view Q7help("Date", code, volume,  prevprice, price) as select "Date", code, volume, lag(price) over (partition by code order by "Date"), price from asx;
create or replace view Q7("Date", Code, Volume, PrevPrice, Price, Change, Gain) as select *, price-prevprice, ((price-prevprice)/prevprice*100) from q7help where prevprice is not null;

-- Q8
create or replace view Q8("Date", Code, Volume) as select "Date", code, volume from asx where volume IN (select MAX(volume) from asx group by "Date" order by "Date");

-- Q9
create or replace view Q9help(industry, number) as select industry, count(code) from category group by industry order by industry;
create or replace view Q9(Sector, Industry, Number) as select distinct a.sector, b.industry, b.number from category a, q9help b where a.industry = b.industry order by sector;

-- Q10
create or replace view Q10(Code, Industry) as select a.code, b.industry from category a, q9help b where b.industry=a.industry and b.number=1;

-- Q11
create or replace view Q11help(sector, code, rating) as select c.sector, r.code, r.star from category c join rating r on c.code = r.code;
create or replace view Q11(Sector, AvgRating) as select sector, avg(rating) from q11help group by sector;

-- Q12
create or replace view Q12(Name) as select person from executive group by person having count(code) > 1;

-- Q13
create or replace view Q13help as select distinct sector from category where code not in (select code from company where country ilike 'Australia');
create or replace view Q13(Code, Name, Address, Zip, Sector) as select a.code, a.name, a.address, a.zip, b.sector from company a join category b on a.code = b.code where b.sector not in (select * from q13help);

-- Q14
create or replace view Q14 (Code, BeginPrice, EndPrice, Change, Gain) as select distinct a.code as code, b.prevprice as prevprice, e.price as price, e.price-b.prevprice as change, ((e.price-b.prevprice)/b.prevprice*100) as gain from q7 a, (select a.code, a.prevprice from q7 a, (select code, min("Date") mindate from q7 group by code) b where a.code=b.code and a."Date"=b.mindate) b, (select a.code, a.price from q7 a, (select code, max("Date") maxdate from q7 group by code) b where a.code=b.code and a."Date"=b.maxdate) e where a.code=b.code and a.code=e.code order by gain desc, code asc;

-- Q15
create or replace view Q15(Code, MinPrice, AvgPrice, MaxPrice, MinDayGain, AvgDayGain, MaxDayGain) as select a.code, a.minprice, a.avgprice, a.maxprice, b.mindaygain, b.avgdaygain, b.maxdaygain  from (select code, min(price) as minprice, avg(price) as avgprice, max(price) as maxprice from asx a group by code) a, (select code, min(gain) as mindaygain, avg(gain) as avgdaygain, max(gain) as maxdaygain from q7 group by code) b where a.code=b.code;

-- Q16
create or replace function Q16() returns trigger as $$
declare
  result text;
begin
  select * into result from Executive where person=new.person;
  if (found) then
    raise exception 'Person is an executive of more than one company';
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists Q16 on Executive;
create trigger Q16 before insert or update on Executive for each row execute procedure Q16();

-- Q17
create or replace view MaxGain("Date", Gain, Sector) as
  select a."Date", max(a.gain), b.sector
  from q7 a inner join category b on a.code=b.code
  group by a."Date", b.sector order by "Date";

create or replace view MinGain("Date", Gain, Sector) as
  select a."Date", min(a.gain), b.sector
  from q7 a inner join category b on a.code=b.code
  group by a."Date", b.sector order by "Date";

create or replace view MaxDayGain("Date", Gain, Sector, Code) as
  select distinct m."Date", m.gain, m.sector, b.code
  from MaxGain m, q7 b, category c
  where m."Date" = (select max("Date") from q7)
  and m.gain=b.gain and m.sector=c.sector
  order by m."Date" desc;

create or replace view MinDayGain("Date", Gain, Sector, Code) as
  select distinct m."Date", m.gain, m.sector, b.code
  from MaxGain m, q7 b, category c
  where m."Date" = (select min("Date") from q7)
  and m.gain=b.gain and m.sector=c.sector
  order by m."Date" desc;

create or replace function Q17() returns trigger as $$
declare
  curr_max record;
  curr_min record;
begin
  for curr_max in (select * from MaxDayGain) loop
    update Rating set star = 5
    where code = curr_max.code;
  end loop;

  for curr_min in (select * from MinDayGain) loop
    update Rating set star = 1
    where code = curr_min.code;
  end loop;

  return new;
end;
$$ language plpgsql;

drop trigger if exists Q17 on asx;
create trigger Q17 after insert on asx for each row execute procedure Q17();

-- Q18
create or replace function Q18() returns trigger as $$
declare
begin
  insert into asxlog values(now(), old."Date", old.volume, old.price);
  return new;
end;
$$ language plpgsql;

drop trigger if exists Q18 on asx;
create trigger Q18 before update on asx for each row execute procedure Q18();
