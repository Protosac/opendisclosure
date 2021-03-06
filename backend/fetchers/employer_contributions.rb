class DataFetcher
  class EmployerContributions
    def self.run!
      ActiveRecord::Base.connection.execute <<-QUERY
        INSERT into employers(employer_name)
        SELECT DISTINCT s.contrib FROM
           (
            SELECT
             CASE
               WHEN p.Emp1 is NULL THEN
                 coalesce(c.employer, 'N/A')
               WHEN p.Emp1 = 'N/A' THEN 
                coalesce((SELECT p1.Emp1
                        FROM maps p1 WHERE p1.Emp2 = c.occupation), c.occupation)
               WHEN p.Emp1 = 'Unemployed' THEN
                coalesce((SELECT p1.Emp1
                        FROM maps p1 WHERE p1.Emp2 = c.occupation), 'Unemployed')
               ELSE p.Emp1
             END AS contrib
              FROM contributions b,
		parties c LEFT OUTER JOIN maps p ON (c.employer = p.Emp2)
              WHERE b.contributor_id = c.id AND c.type = 'Party::Individual'
            UNION ALL
            SELECT coalesce(p.Emp1, c.name) AS contrib
              FROM contributions b,
                parties c LEFT OUTER JOIN maps p ON c.name = p.Emp2
              WHERE b.contributor_id = c.id AND c.type <> 'Party::Individual'
           ) s
      QUERY
      ActiveRecord::Base.connection.execute <<-QUERY
        UPDATE parties c SET employer_id = e.id
        FROM employers e, maps p
        WHERE CASE
          WHEN p.Emp1 = 'N/A' THEN 
		coalesce((SELECT p1.Emp1
			FROM maps p1 WHERE p1.Emp2 = c.occupation), c.occupation)
	  WHEN p.Emp1 = 'Unemployed' THEN
		coalesce((SELECT p1.Emp1
			FROM maps p1 WHERE p1.Emp2 = c.occupation), 'Unemployed')
          ELSE p.Emp1
        END = e.employer_name AND
        c.employer = p.Emp2 AND c.type = 'Party::Individual'
      QUERY
      ActiveRecord::Base.connection.execute <<-QUERY
        UPDATE parties c SET employer_id = e.id
        FROM employers e, maps p
        WHERE p.Emp1 = e.employer_name AND
        c.name = p.Emp2 AND c.type <> 'Party::Individual'
      QUERY
      ActiveRecord::Base.connection.execute <<-QUERY
        INSERT into employer_contributions(recipient_id, employer_id, name, contrib, amount)
        SELECT r.id, e.id, r.name, e.employer_name, sum(amount) as amount
        FROM contributions b, parties r, parties c, employers e
        WHERE b.recipient_id = r.id AND b.contributor_id = c.id AND e.id = c.employer_id
          AND r.committee_id in (#{Party::MAYORAL_CANDIDATE_IDS.join ','})
        GROUP BY e.id, r.id
      QUERY
    end
  end
end
