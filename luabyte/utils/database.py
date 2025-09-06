
import psycopg2

class Database():
    def __init__(self, database_name):
        self.database = psycopg2.connect(database=database_name, user="postgres",
                                            password="postgres", host="127.0.0.1",
                                            port=5432)
    
    def execute(self, query_str, params):
        if self.database:
            try:
                results = ""
                cur = self.database.cursor()
                cur.execute(query_str, params)
                if query_str.strip().upper().startswith(('INSERT', 'UPDATE', 'DELETE')):  
                    self.database.commit()
                if query_str.strip().upper().startswith(('SELECT')):  
                    results = cur.fetchall()    
                elif query_str.strip().upper().startswith(('INSERT', 'UPDATE', 'DELETE')):
                    results = cur.rowcount # the row num affected
            except BaseException as e:
                self.database.rollback()
                # set_trace()
                logger.warning("Database connection exception: %s!" % e)
                logger.warning("Fail item: %s" % str(params))
            finally:
                if self.database and cur:
                    cur.close()
            return results
