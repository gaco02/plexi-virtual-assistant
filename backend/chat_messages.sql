PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE chat_messages (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    content TEXT NOT NULL,
                    is_user BOOLEAN NOT NULL,
                    timestamp DATETIME NOT NULL,
                    tool_used TEXT,
                    tool_response TEXT,
                    conversation_id TEXT,
                    FOREIGN KEY (user_id) REFERENCES users(firebase_uid)
                );
INSERT INTO chat_messages VALUES(1,'JCIttv58H1VFQPMlygFdPfpR84B2','how much did i spend today?',1,'2025-03-04T18:50:10.016511',NULL,NULL,NULL);
INSERT INTO chat_messages VALUES(2,'JCIttv58H1VFQPMlygFdPfpR84B2','I''ve processed your budget information.',0,'2025-03-04T18:50:10.016511','budget','{"expense_info": {"error": "No user preferences found"}, "calorie_info": null, "restaurant_suggestions": null}',NULL);
INSERT INTO chat_messages VALUES(3,'JCIttv58H1VFQPMlygFdPfpR84B2','how much did i spend today?',1,'2025-03-04T18:52:08.156959',NULL,NULL,NULL);
INSERT INTO chat_messages VALUES(4,'JCIttv58H1VFQPMlygFdPfpR84B2','I''ve processed your budget information.',0,'2025-03-04T18:52:08.156959','budget','{"expense_info": {"error": "No user preferences found"}, "calorie_info": null, "restaurant_suggestions": null}',NULL);
INSERT INTO chat_messages VALUES(5,'JCIttv58H1VFQPMlygFdPfpR84B2','how much did i spend today?',1,'2025-03-04T18:52:08.156959',NULL,NULL,NULL);
INSERT INTO chat_messages VALUES(6,'JCIttv58H1VFQPMlygFdPfpR84B2','I''ve processed your budget information.',0,'2025-03-04T18:52:08.156959','budget','{"expense_info": {"error": "No user preferences found"}, "calorie_info": null, "restaurant_suggestions": null}',NULL);
INSERT INTO chat_messages VALUES(7,'JCIttv58H1VFQPMlygFdPfpR84B2','how many calories did I eat today?',1,'2025-03-04T18:52:08.156959','calories',NULL,NULL);
INSERT INTO chat_messages VALUES(8,'JCIttv58H1VFQPMlygFdPfpR84B2','I''m having trouble processing that right now. Could you please try again?',0,'2025-03-04T18:52:08.156959',NULL,'{"expense_info": null, "calorie_info": null, "restaurant_suggestions": null}',NULL);
INSERT INTO chat_messages VALUES(9,'JCIttv58H1VFQPMlygFdPfpR84B2','how much did i spend today?',1,'2025-03-04T18:52:08.156959',NULL,NULL,NULL);
INSERT INTO chat_messages VALUES(10,'JCIttv58H1VFQPMlygFdPfpR84B2','I''ve processed your budget information.',0,'2025-03-04T18:52:08.156959','budget','{"expense_info": {"error": "No user preferences found"}, "calorie_info": null, "restaurant_suggestions": null}',NULL);
INSERT INTO chat_messages VALUES(11,'JCIttv58H1VFQPMlygFdPfpR84B2','how much did i spend today?',1,'2025-03-04T18:52:08.156959',NULL,NULL,NULL);
INSERT INTO chat_messages VALUES(12,'JCIttv58H1VFQPMlygFdPfpR84B2','I''ve processed your budget information.',0,'2025-03-04T18:52:08.156959','budget','{"expense_info": {"error": "No user preferences found"}, "calorie_info": null, "restaurant_suggestions": null}',NULL);
INSERT INTO chat_messages VALUES(13,'JCIttv58H1VFQPMlygFdPfpR84B2','how many calories did I eat today?',1,'2025-03-04T18:52:08.156959','calories',NULL,NULL);
INSERT INTO chat_messages VALUES(14,'JCIttv58H1VFQPMlygFdPfpR84B2','I''m having trouble processing that right now. Could you please try again?',0,'2025-03-04T18:52:08.156959',NULL,'{"expense_info": null, "calorie_info": null, "restaurant_suggestions": null}',NULL);
INSERT INTO chat_messages VALUES(15,'JCIttv58H1VFQPMlygFdPfpR84B2','how many calories did I eat today?',1,'2025-03-04T18:52:08.156959','calories',NULL,NULL);
INSERT INTO chat_messages VALUES(16,'JCIttv58H1VFQPMlygFdPfpR84B2','I''m having trouble processing that right now. Could you please try again?',0,'2025-03-04T18:52:08.156959',NULL,'{"expense_info": null, "calorie_info": null, "restaurant_suggestions": null}',NULL);
INSERT INTO chat_messages VALUES(17,'JCIttv58H1VFQPMlygFdPfpR84B2','how much did i spend today?',1,'2025-03-04T18:52:08.156959',NULL,NULL,NULL);
INSERT INTO chat_messages VALUES(18,'JCIttv58H1VFQPMlygFdPfpR84B2','I''ve processed your budget information.',0,'2025-03-04T18:52:08.156959','budget','{"expense_info": {"error": "No user preferences found"}, "calorie_info": null, "restaurant_suggestions": null}',NULL);
INSERT INTO chat_messages VALUES(19,'JCIttv58H1VFQPMlygFdPfpR84B2','how much did i spend today?',1,'2025-03-04T18:52:08.156959',NULL,NULL,NULL);
INSERT INTO chat_messages VALUES(20,'JCIttv58H1VFQPMlygFdPfpR84B2','I''ve processed your budget information.',0,'2025-03-04T18:52:08.156959','budget','{"expense_info": {"error": "No user preferences found"}, "calorie_info": null, "restaurant_suggestions": null}',NULL);
INSERT INTO chat_messages VALUES(21,'JCIttv58H1VFQPMlygFdPfpR84B2','how much did i spend today?',1,'2025-03-04T18:52:08.156959',NULL,NULL,NULL);
INSERT INTO chat_messages VALUES(22,'JCIttv58H1VFQPMlygFdPfpR84B2','I''ve processed your budget information.',0,'2025-03-04T18:52:08.156959','budget','{"expense_info": {"error": "No user preferences found"}, "calorie_info": null, "restaurant_suggestions": null}',NULL);
INSERT INTO chat_messages VALUES(23,'JCIttv58H1VFQPMlygFdPfpR84B2','how many calories did I eat today?',1,'2025-03-04T18:52:08.156959','calories',NULL,NULL);
INSERT INTO chat_messages VALUES(24,'JCIttv58H1VFQPMlygFdPfpR84B2','I''m having trouble processing that right now. Could you please try again?',0,'2025-03-04T18:52:08.156959',NULL,'{"expense_info": null, "calorie_info": null, "restaurant_suggestions": null}',NULL);
INSERT INTO chat_messages VALUES(25,'JCIttv58H1VFQPMlygFdPfpR84B2','how much did i spend today?',1,'2025-03-04T18:52:08.156959',NULL,NULL,NULL);
INSERT INTO chat_messages VALUES(26,'JCIttv58H1VFQPMlygFdPfpR84B2','I''ve processed your budget information.',0,'2025-03-04T18:52:08.156959','budget','{"expense_info": {"error": "No user preferences found"}, "calorie_info": null, "restaurant_suggestions": null}',NULL);
INSERT INTO chat_messages VALUES(27,'JCIttv58H1VFQPMlygFdPfpR84B2','how much did i spend today?',1,'2025-03-04T18:55:54.124989',NULL,NULL,NULL);
INSERT INTO chat_messages VALUES(28,'JCIttv58H1VFQPMlygFdPfpR84B2','I''ve processed your budget information.',0,'2025-03-04T18:55:54.124989','budget','{"expense_info": {"error": "No user preferences found"}, "calorie_info": null, "restaurant_suggestions": null}',NULL);
INSERT INTO chat_messages VALUES(29,'JCIttv58H1VFQPMlygFdPfpR84B2','how much did i spend today?',1,'2025-03-04T18:55:54.124989',NULL,NULL,NULL);
INSERT INTO chat_messages VALUES(30,'JCIttv58H1VFQPMlygFdPfpR84B2','I''ve processed your budget information.',0,'2025-03-04T18:55:54.124989','budget','{"expense_info": {"error": "No user preferences found"}, "calorie_info": null, "restaurant_suggestions": null}',NULL);
COMMIT;
