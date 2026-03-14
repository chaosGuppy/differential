UPDATE page_links SET role = 'direct';
ALTER TABLE page_links ALTER COLUMN role SET DEFAULT 'direct';
