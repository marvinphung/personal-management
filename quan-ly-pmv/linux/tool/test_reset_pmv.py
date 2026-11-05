"""Integration tests: explicitly selected loopback PostgreSQL only."""
import os
import unittest
import uuid
from urllib.parse import urlparse
import psycopg
from reset_pmv import reset_user

class ScopedResetTest(unittest.TestCase):
    def test_linked_notes_are_deleted_first_and_other_user_is_preserved(self):
        url=os.environ.get('PMV_TEST_DATABASE_URL','')
        parsed=urlparse(url)
        self.assertIn(parsed.hostname,('127.0.0.1','localhost'))
        self.assertEqual(parsed.port,55439)
        with psycopg.connect(url) as c:
            try:
                target=str(uuid.uuid4()); other=str(uuid.uuid4()); person=str(uuid.uuid4()); debt=str(uuid.uuid4()); tx=str(uuid.uuid4()); account=str(uuid.uuid4())
                c.execute('insert into auth.users(id) values(%s),(%s)',(target,other))
                c.execute("insert into public.people(id,user_id,name,mutation_id) values(%s,%s,'Synthetic',gen_random_uuid())",(person,target))
                c.execute("insert into public.accounts(id,user_id,name,type,mutation_id) values(%s,%s,'Cash','cash',gen_random_uuid())",(account,target))
                c.execute("insert into public.transactions(id,user_id,type,amount,occurred_at,mutation_id,account_id) values(%s,%s,'expense',10,now(),gen_random_uuid(),%s)",(tx,target,account))
                c.execute("insert into public.debts(id,user_id,person_id,direction,principal_amount,started_at,mutation_id) values(%s,%s,%s,'lent',10,now(),gen_random_uuid())",(debt,target,person))
                c.execute("insert into public.notes(id,user_id,title,debt_id,transaction_id,mutation_id) values(gen_random_uuid(),%s,'Linked',%s,%s,gen_random_uuid()),(gen_random_uuid(),%s,'Other',null,null,gen_random_uuid())",(target,debt,tx,other))
                counts=reset_user(c,target)
                self.assertEqual(counts['notes'],1)
                self.assertEqual(c.execute('select count(*) from public.debts where user_id=%s',(target,)).fetchone()[0],1)
                reset_user(c,target,execute=True,seed=True)
                self.assertEqual(c.execute('select count(*) from public.debts where user_id=%s',(target,)).fetchone()[0],0)
                self.assertEqual(c.execute('select count(*) from public.categories where user_id=%s',(target,)).fetchone()[0],19)
                self.assertEqual(c.execute('select count(*) from public.notes where user_id=%s',(other,)).fetchone()[0],1)
                self.assertEqual(c.execute('select count(*) from auth.users where id in (%s,%s)',(target,other)).fetchone()[0],2)
            finally:c.rollback()

if __name__=='__main__':unittest.main()
